import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:employee_app/features/attendance/domain/attendance_models.dart';
import 'package:employee_app/features/attendance/presentation/attendance_bloc.dart';
import 'package:employee_app/features/dashboard/presentation/dashboard_bloc.dart';
import 'package:employee_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:employee_app/features/leave/presentation/leave_bloc.dart';
import 'package:mocktail/mocktail.dart';

class MockAttendanceCubit extends Mock implements AttendanceCubit {}
class MockDashboardCubit extends Mock implements DashboardCubit {}
class MockLeaveCubit extends Mock implements LeaveCubit {}

void main() {
  late MockAttendanceCubit mockAttendanceCubit;
  late MockDashboardCubit mockDashboardCubit;
  late MockLeaveCubit mockLeaveCubit;

  setUp(() {
    mockAttendanceCubit = MockAttendanceCubit();
    mockDashboardCubit = MockDashboardCubit();
    mockLeaveCubit = MockLeaveCubit();

    // Stream stubbing for cubits
    when(() => mockAttendanceCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockDashboardCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockLeaveCubit.stream).thenAnswer((_) => const Stream.empty());

    when(() => mockAttendanceCubit.loadAttendanceData(silent: any(named: 'silent'))).thenAnswer((_) async {});
    when(() => mockDashboardCubit.loadDashboard(forceRefresh: any(named: 'forceRefresh'))).thenAnswer((_) async {});
    when(() => mockLeaveCubit.loadLeaveData()).thenAnswer((_) async {});
  });

  testWidgets('Dashboard renders Pending Sync badge when local record is unsynced', (WidgetTester tester) async {
    final pendingRecord = AttendanceRecord(
      id: 'rec_pending_1',
      clientEventId: 'client_event_pending_1',
      employeeId: 'EMP-1049',
      date: '2026-11-17',
      type: AttendanceType.checkIn,
      timestamp: DateTime(2026, 11, 17, 9, 30),
      latitude: 12.9716,
      longitude: 77.5946,
      syncStatus: SyncStatus.pending,
      createdAt: DateTime(2026, 11, 17, 9, 30),
    );

    when(() => mockAttendanceCubit.state).thenReturn(
      AttendanceState(
        todayStatus: TodayAttendanceStatus.checkedIn,
        checkInRecord: pendingRecord,
        pendingSyncCount: 1,
        recentRecords: [pendingRecord],
      ),
    );

    when(() => mockDashboardCubit.state).thenReturn(
      const DashboardState(),
    );

    when(() => mockLeaveCubit.state).thenReturn(
      const LeaveState(),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AttendanceCubit>.value(value: mockAttendanceCubit),
          BlocProvider<DashboardCubit>.value(value: mockDashboardCubit),
          BlocProvider<LeaveCubit>.value(value: mockLeaveCubit),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    // Initial frame
    await tester.pump();

    // Verify today's status displays 'Checked In'
    expect(find.text('Checked In'), findsWidgets);

    // Verify 'Pending Sync' text badge is rendered
    expect(find.text('Pending Sync'), findsWidgets);

    // Verify the pending count badge on the sync icon displays '1'
    expect(find.text('1'), findsWidgets);
  });
}
