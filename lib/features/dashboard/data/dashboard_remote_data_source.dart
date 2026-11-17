import '../../../core/network/api_client.dart';
import '../domain/employee_profile.dart';

class DashboardRemoteDataSource {
  final ApiClient apiClient;

  DashboardRemoteDataSource({ApiClient? client}) : apiClient = client ?? ApiClient();

  Future<EmployeeProfile> fetchEmployeeProfile() async {
    final response = await apiClient.dio.get('/employee/me');
    final data = response.data as Map<String, dynamic>;
    return EmployeeProfile.fromJson(data);
  }
}
