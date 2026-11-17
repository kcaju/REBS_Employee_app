import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../domain/leave_models.dart';
import '../domain/leave_validator.dart';
import 'leave_local_data_source.dart';
import 'leave_remote_data_source.dart';

class LeaveRepository {
  final LeaveLocalDataSource localDataSource;
  final LeaveRemoteDataSource remoteDataSource;
  final Connectivity connectivity;

  LeaveRepository({
    LeaveLocalDataSource? local,
    LeaveRemoteDataSource? remote,
    Connectivity? connectivity,
  })  : localDataSource = local ?? LeaveLocalDataSource(),
        remoteDataSource = remote ?? LeaveRemoteDataSource(),
        connectivity = connectivity ?? Connectivity();

  Future<LeaveBalance> getLeaveBalance() async {
    try {
      final balance = await remoteDataSource.fetchLeaveBalance();
      return balance;
    } catch (_) {
      // Fallback default balance if offline
      return const LeaveBalance(casualLeaveRemaining: 8, sickLeaveRemaining: 5);
    }
  }

  Future<List<LeaveRequest>> getLeaveRequests({bool forceRefresh = false}) async {
    try {
      final remoteList = await remoteDataSource.fetchLeaveRequests();
      await localDataSource.saveLeaveRequests(remoteList);
      return remoteList;
    } catch (_) {
      // Offline fallback: load cached requests from SQLite
      return await localDataSource.getLeaveRequests();
    }
  }

  Future<LeaveRequest> submitLeave({
    required String employeeId,
    required LeaveType type,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required int availableBalance,
  }) async {
    // 1. Fetch current requests for overlap validation
    final currentRequests = await localDataSource.getLeaveRequests();

    // 2. Perform client-side validation
    final validation = LeaveValidator.validate(
      leaveType: type,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      availableBalance: availableBalance,
      existingRequests: currentRequests,
    );

    if (!validation.isValid) {
      throw Exception(validation.errorMessage);
    }

    final newRequest = LeaveRequest(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      employeeId: employeeId,
      leaveType: type,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      status: LeaveStatus.pending,
      createdAt: DateTime.now(),
    );

    // 3. Connectivity check (Leave submission requires connectivity as per assignment)
    final connectivityResult = await connectivity.checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none) || connectivityResult.isEmpty) {
      throw Exception('No network connection. Leave submission requires active connectivity.');
    }

    // 4. Remote Submission
    try {
      final created = await remoteDataSource.submitLeaveRequest(newRequest);
      await localDataSource.saveSingleRequest(created);
      return created;
    } on DioException catch (dioError) {
      if (dioError.response?.statusCode == 422 || dioError.response?.statusCode == 400) {
        final serverMessage = dioError.response?.data is Map
            ? dioError.response?.data['error'] ?? dioError.response?.data['message'] ?? 'Server validation failed'
            : 'Server validation error';
        throw Exception(serverMessage);
      } else if (dioError.type == DioExceptionType.connectionError ||
          dioError.type == DioExceptionType.connectionTimeout) {
        throw Exception('No network connection. Leave submission requires active connectivity.');
      } else {
        final serverMessage = dioError.response?.data is Map
            ? dioError.response?.data['error'] ?? dioError.response?.data['message']
            : null;
        throw Exception(serverMessage ?? 'Server error: ${dioError.message}');
      }
    }
  }
}
