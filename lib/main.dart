import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/database/app_database.dart';
import 'core/services/sync_queue_manager.dart';
import 'features/attendance/data/attendance_local_data_source.dart';
import 'features/attendance/data/attendance_remote_data_source.dart';
import 'features/attendance/data/attendance_repository_impl.dart';
import 'features/attendance/presentation/attendance_bloc.dart';
import 'features/dashboard/data/dashboard_repository_impl.dart';
import 'features/dashboard/presentation/dashboard_bloc.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/leave/data/leave_repository_impl.dart';
import 'features/leave/presentation/leave_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite database
  await AppDatabase.instance.database;

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

  final leaveRepository = LeaveRepository();
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
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          scaffoldBackgroundColor: const Color(0xFFF7F9FC),
          cardTheme: const CardThemeData(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}
