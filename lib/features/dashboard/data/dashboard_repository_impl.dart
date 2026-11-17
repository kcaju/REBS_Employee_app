import '../domain/employee_profile.dart';
import 'dashboard_remote_data_source.dart';
import 'profile_local_data_source.dart';

class DashboardRepository {
  final DashboardRemoteDataSource remoteDataSource;
  final ProfileLocalDataSource localDataSource;

  DashboardRepository({
    DashboardRemoteDataSource? remote,
    ProfileLocalDataSource? local,
  })  : remoteDataSource = remote ?? DashboardRemoteDataSource(),
        localDataSource = local ?? ProfileLocalDataSource();

  Future<EmployeeProfile> getProfile({bool forceRefresh = false}) async {
    // 1. Try remote
    try {
      final remoteProfile = await remoteDataSource.fetchEmployeeProfile();
      await localDataSource.saveProfile(remoteProfile);
      return remoteProfile;
    } catch (_) {
      // 2. Offline fallback from SQLite
      final cached = await localDataSource.getProfile();
      if (cached != null) {
        return cached;
      }
      // 3. Fallback default preconfigured employee
      return const EmployeeProfile(
        id: 'EMP-1049',
        name: 'Arjun K C',
        email: 'arjun.kc@rebs.io',
        department: 'Mobile Engineering',
        role: 'Flutter Developer',
        casualLeaveRemaining: 8,
        sickLeaveRemaining: 5,
        officeConfig: OfficeConfig(
          latitude: 9.9816,
          longitude: 76.2999,
          radiusMeters: 200.0,
          officeName: 'REBS Tech Center - Ernakulam, Kerala',
          timezone: 'Asia/Kolkata',
        ),
      );
    }
  }
}
