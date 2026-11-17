import 'package:uuid/uuid.dart';
import '../domain/attendance_models.dart';
import 'attendance_local_data_source.dart';
import 'attendance_remote_data_source.dart';
import '../../../core/services/sync_queue_manager.dart';

class AttendanceRepository {
  final AttendanceLocalDataSource localDataSource;
  final AttendanceRemoteDataSource remoteDataSource;
  final SyncQueueManager syncQueueManager;
  final Uuid uuid;

  AttendanceRepository({
    AttendanceLocalDataSource? local,
    AttendanceRemoteDataSource? remote,
    SyncQueueManager? sync,
    Uuid? uuidGen,
  })  : localDataSource = local ?? AttendanceLocalDataSource(),
        remoteDataSource = remote ?? AttendanceRemoteDataSource(),
        syncQueueManager = sync ?? SyncQueueManager(),
        uuid = uuidGen ?? const Uuid();

  Future<List<AttendanceRecord>> getLatestRecords({int limit = 5}) async {
    // 1. Try to fetch from remote if possible and merge
    try {
      final remoteRecords = await remoteDataSource.fetchAttendanceHistory();
      for (final r in remoteRecords) {
        await localDataSource.saveRecord(r.copyWith(syncStatus: SyncStatus.synced));
      }
    } catch (_) {
      // Offline fallback: continue with local records
    }

    return await localDataSource.getLatestRecords(limit: limit);
  }

  Future<Map<String, AttendanceRecord?>> getTodayAttendanceSession(String date) async {
    final records = await localDataSource.getRecordsForDate(date);
    AttendanceRecord? checkIn;
    AttendanceRecord? checkOut;

    for (final r in records) {
      if (r.type == AttendanceType.checkIn && checkIn == null) {
        checkIn = r;
      } else if (r.type == AttendanceType.checkOut && checkOut == null) {
        checkOut = r;
      }
    }

    return {'checkIn': checkIn, 'checkOut': checkOut};
  }

  /// Records attendance locally first (optimistic), then triggers sync
  Future<AttendanceRecord> recordAttendance({
    required AttendanceType type,
    required double latitude,
    required double longitude,
    required String employeeId,
    required String date,
  }) async {
    final now = DateTime.now();
    final clientEventId = uuid.v4(); // Unique Idempotency Key

    // Business rule checks before write:
    final todaySession = await getTodayAttendanceSession(date);
    if (type == AttendanceType.checkIn && todaySession['checkIn'] != null) {
      throw Exception('Already checked in for today ($date). Only one check-in allowed per working day.');
    }
    if (type == AttendanceType.checkOut) {
      if (todaySession['checkIn'] == null) {
        throw Exception('Cannot check out without checking in first.');
      }
      if (todaySession['checkOut'] != null) {
        throw Exception('Already checked out for today ($date).');
      }
    }

    final newRecord = AttendanceRecord(
      id: 'local_${now.millisecondsSinceEpoch}',
      clientEventId: clientEventId,
      employeeId: employeeId,
      date: date,
      type: type,
      timestamp: now,
      latitude: latitude,
      longitude: longitude,
      syncStatus: SyncStatus.pending,
      createdAt: now,
    );

    // 1. Save to local SQLite database immediately (survives app restart)
    await localDataSource.saveRecord(newRecord);

    // 2. Trigger asynchronous background sync
    syncQueueManager.processQueue();

    return newRecord;
  }

  Future<int> syncPendingEvents() async {
    return await syncQueueManager.processQueue(force: true);
  }

  Future<void> resetTodaySession(String date) async {
    await localDataSource.deleteRecordsForDate(date);
    try {
      await remoteDataSource.apiClient.dio.post('/debug/reset');
    } catch (_) {}
  }
}
