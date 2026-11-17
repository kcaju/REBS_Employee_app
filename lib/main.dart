import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/database/app_database.dart';
import 'core/network/api_client.dart';
import 'core/services/sync_queue_manager.dart';
import 'features/attendance/data/attendance_local_data_source.dart';
import 'features/attendance/data/attendance_remote_data_source.dart';
import 'features/attendance/data/attendance_repository_impl.dart';
import 'features/attendance/presentation/attendance_bloc.dart';
import 'features/dashboard/data/dashboard_repository_impl.dart';
import 'features/dashboard/presentation/dashboard_bloc.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/leave/data/leave_local_data_source.dart';
import 'features/leave/data/leave_repository_impl.dart';
import 'features/leave/presentation/leave_bloc.dart';
import 'server/embedded_mock_server.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite database
  await AppDatabase.instance.database;

  // Initialize Leave Local Data Source and ensure seed records exist
  final leaveLocalDS = LeaveLocalDataSource();
  await leaveLocalDS.ensureInitialSeeds();
  final existingLeaves = await leaveLocalDS.getLeaveRequests();

  // Start Embedded Local Mock Server automatically (100% Standalone APK Mode)
  try {
    final serverPort = await EmbeddedMockServer.instance.start(defaultPort: 8085);
    EmbeddedMockServer.instance.syncInitialState(
      existingLeaves.map((r) => r.toMap()).toList(),
    );
    ApiConfig.defaultBaseUrl = 'http://127.0.0.1:$serverPort';
    ApiConfig.activeBaseUrl = ApiConfig.defaultBaseUrl;
  } catch (_) {
    // Falls back gracefully if running in constrained environment
  }

  // Initialize Shared Data Sources & Services
  final attendanceLocalDS = AttendanceLocalDataSource();
  final attendanceRemoteDS = AttendanceRemoteDataSource();
  final syncQueueManager = SyncQueueManager(
    local: attendanceLocalDS,
    remote: attendanceRemoteDS,
  );

  // Initialize Repositories
  final attendanceRepository = AttendanceRepository(
    local: attendanceLocalDS,
    remote: attendanceRemoteDS,
    sync: syncQueueManager,
  );

  final leaveRepository = LeaveRepository(local: leaveLocalDS);
  final dashboardRepository = DashboardRepository();

  runApp(
    MyApp(
      attendanceRepository: attendanceRepository,
      leaveRepository: leaveRepository,
      dashboardRepository: dashboardRepository,
      syncQueueManager: syncQueueManager,
    ),
  );
}

class MyApp extends StatelessWidget {
  final AttendanceRepository attendanceRepository;
  final LeaveRepository leaveRepository;
  final DashboardRepository dashboardRepository;
  final SyncQueueManager syncQueueManager;

  const MyApp({
    super.key,
    required this.attendanceRepository,
    required this.leaveRepository,
    required this.dashboardRepository,
    required this.syncQueueManager,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DashboardCubit>(
          create: (_) => DashboardCubit(repository: dashboardRepository),
        ),
        BlocProvider<AttendanceCubit>(
          create: (_) => AttendanceCubit(
            repository: attendanceRepository,
            syncManager: syncQueueManager,
          ),
        ),
        BlocProvider<LeaveCubit>(
          create: (_) => LeaveCubit(repository: leaveRepository),
        ),
      ],
      child: MaterialApp(
        title: 'REBS Employee Workspace',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const DashboardScreen(),
      ),
    );
  }
}
