import '../../../core/network/api_client.dart';
import '../domain/leave_models.dart';

class LeaveRemoteDataSource {
  final ApiClient apiClient;

  LeaveRemoteDataSource({ApiClient? client}) : apiClient = client ?? ApiClient();

  Future<LeaveBalance> fetchLeaveBalance() async {
    final response = await apiClient.dio.get('/leave/balance');
    final data = response.data as Map<String, dynamic>;
    return LeaveBalance(
      casualLeaveRemaining: data['casual_leave_remaining'] as int? ?? 0,
      sickLeaveRemaining: data['sick_leave_remaining'] as int? ?? 0,
    );
  }

  Future<List<LeaveRequest>> fetchLeaveRequests() async {
    final response = await apiClient.dio.get('/leave/requests');
    final data = response.data as Map<String, dynamic>;
    final list = data['requests'] as List<dynamic>;
    return list.map((item) => LeaveRequest.fromMap(item as Map<String, dynamic>)).toList();
  }

  Future<LeaveRequest> submitLeaveRequest(LeaveRequest request) async {
    final response = await apiClient.dio.post(
      '/leave/requests',
      data: {
        'employee_id': request.employeeId,
        'leave_type': request.leaveType == LeaveType.casual ? 'Casual' : 'Sick',
        'start_date': request.startDate.toIso8601String().substring(0, 10),
        'end_date': request.endDate.toIso8601String().substring(0, 10),
        'reason': request.reason,
      },
    );

    final data = response.data as Map<String, dynamic>;
    return LeaveRequest.fromMap(data['request'] as Map<String, dynamic>);
  }
}
