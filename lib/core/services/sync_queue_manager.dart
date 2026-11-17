import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../../features/attendance/data/attendance_local_data_source.dart';
import '../../features/attendance/data/attendance_remote_data_source.dart';
import '../../features/attendance/domain/attendance_models.dart';

class SyncStatusUpdate {
  final bool isSyncing;
  final int pendingCount;
  final String? lastMessage;

  const SyncStatusUpdate({
    required this.isSyncing,
    required this.pendingCount,
    this.lastMessage,
  });
}

class SyncQueueManager {
  final AttendanceLocalDataSource localDataSource;
  final AttendanceRemoteDataSource remoteDataSource;
  final Connectivity connectivity;

  final _statusController = StreamController<SyncStatusUpdate>.broadcast();
  Stream<SyncStatusUpdate> get statusStream => _statusController.stream;

  StreamSubscription? _connectivitySubscription;
  bool _isProcessing = false;

  SyncQueueManager({
    AttendanceLocalDataSource? local,
    AttendanceRemoteDataSource? remote,
    Connectivity? conn,
  })  : localDataSource = local ?? AttendanceLocalDataSource(),
        remoteDataSource = remote ?? AttendanceRemoteDataSource(),
        connectivity = conn ?? Connectivity() {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        processQueue();
      }
    });
  }

  /// Processes pending attendance events in strict FIFO order (timestamp ASC)
  Future<int> processQueue() async {
    if (_isProcessing) return 0;
    _isProcessing = true;

    try {
      final pendingRecords = await localDataSource.getPendingSyncRecords();
      _notify(isSyncing: true, pendingCount: pendingRecords.length, message: 'Syncing pending records...');

      int syncedCount = 0;

      for (final record in pendingRecords) {
        try {
          await remoteDataSource.submitAttendanceEvent(record);

          // Successfully synced on server
          await localDataSource.updateSyncStatus(
            record.clientEventId,
            SyncStatus.synced,
          );
          syncedCount++;
        } on DioException catch (dioError) {
          final statusCode = dioError.response?.statusCode;

          if (statusCode == 409) {
            // Server conflict: attendance already exists on server
            final message = dioError.response?.data is Map
                ? dioError.response?.data['error'] ?? 'Attendance conflict'
                : 'Attendance already recorded on server';

            await localDataSource.updateSyncStatus(
              record.clientEventId,
              SyncStatus.rejected,
              rejectionReason: message.toString(),
            );
          } else if (dioError.type == DioExceptionType.connectionTimeout ||
              dioError.type == DioExceptionType.sendTimeout ||
              dioError.type == DioExceptionType.receiveTimeout ||
              dioError.type == DioExceptionType.connectionError) {
            // Network timeout / offline: Stop queue processing so order is preserved on retry
            _notify(
              isSyncing: false,
              pendingCount: pendingRecords.length - syncedCount,
              message: 'Connection timeout. Retaining pending items for next sync.',
            );
            return syncedCount;
          } else {
            // Other server error (e.g. 500)
            _notify(
              isSyncing: false,
              pendingCount: pendingRecords.length - syncedCount,
              message: 'Server error: ${dioError.message}',
            );
            return syncedCount;
          }
        } catch (e) {
          // General failure
          _notify(
            isSyncing: false,
            pendingCount: pendingRecords.length - syncedCount,
            message: 'Sync error: $e',
          );
          return syncedCount;
        }
      }

      final remaining = await localDataSource.getPendingSyncRecords();
      _notify(
        isSyncing: false,
        pendingCount: remaining.length,
        message: syncedCount > 0 ? 'Successfully synced $syncedCount record(s)' : 'All records up to date',
      );
      return syncedCount;
    } finally {
      _isProcessing = false;
    }
  }

  void _notify({required bool isSyncing, required int pendingCount, String? message}) {
    if (!_statusController.isClosed) {
      _statusController.add(
        SyncStatusUpdate(
          isSyncing: isSyncing,
          pendingCount: pendingCount,
          lastMessage: message,
        ),
      );
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
  }
}
