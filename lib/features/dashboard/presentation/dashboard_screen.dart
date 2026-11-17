import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../attendance/domain/attendance_models.dart';
import '../../attendance/presentation/attendance_bloc.dart';
import '../../leave/presentation/leave_bloc.dart';
import '../../leave/presentation/leave_history_screen.dart';
import '../../dev_settings/dev_drawer.dart';
import 'dashboard_bloc.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _tickerTimer;
  Duration _elapsedDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTicker();
    _loadInitialData();
  }

  void _loadInitialData() {
    context.read<DashboardCubit>().loadDashboard();
    context.read<AttendanceCubit>().loadAttendanceData();
    context.read<LeaveCubit>().loadLeaveData();
  }

  void _startTicker() {
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final attendanceState = context.read<AttendanceCubit>().state;
      if (attendanceState.todayStatus == TodayAttendanceStatus.checkedIn &&
          attendanceState.checkInRecord != null) {
        setState(() {
          _elapsedDuration = DateTime.now().difference(
            attendanceState.checkInRecord!.timestamp,
          );
        });
      } else if (attendanceState.todayStatus ==
              TodayAttendanceStatus.checkedOut &&
          attendanceState.checkInRecord != null &&
          attendanceState.checkOutRecord != null) {
        setState(() {
          _elapsedDuration = attendanceState.checkOutRecord!.timestamp
              .difference(attendanceState.checkInRecord!.timestamp);
        });
      } else {
        if (_elapsedDuration != Duration.zero) {
          setState(() {
            _elapsedDuration = Duration.zero;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text(
            'REBS Workspace',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            // Manual Sync Now button with indicator
            BlocBuilder<AttendanceCubit, AttendanceState>(
              builder: (context, state) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: state.isSyncing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync, color: Colors.white),
                      tooltip: 'Sync Now',
                      onPressed: state.isSyncing
                          ? null
                          : () => context.read<AttendanceCubit>().syncNow(),
                    ),
                    if (state.pendingSyncCount > 0 && !state.isSyncing)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${state.pendingSyncCount}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            // Reviewer Dev Drawer Trigger
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                tooltip: 'Reviewer Controls',
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              ),
            ),
          ],
        ),
        endDrawer: DevSettingsDrawer(
          onSettingsChanged: () {
            _loadInitialData();
          },
        ),
        body: RefreshIndicator(
          color: AppTheme.purplePrimary,
          onRefresh: () async {
            final dashboardCubit = context.read<DashboardCubit>();
            final attendanceCubit = context.read<AttendanceCubit>();
            final leaveCubit = context.read<LeaveCubit>();

            await Future.wait([
              dashboardCubit.loadDashboard(forceRefresh: true),
              attendanceCubit.loadAttendanceData(),
              leaveCubit.loadLeaveData(),
            ]);
          },
          child: MultiBlocListener(
            listeners: [
              BlocListener<AttendanceCubit, AttendanceState>(
                listenWhen: (previous, current) =>
                    (previous.errorMessage != current.errorMessage && current.errorMessage != null) ||
                    (previous.successMessage != current.successMessage && current.successMessage != null),
                listener: (context, state) {
                  if (state.errorMessage != null) {
                    AppSnackBar.showError(context, state.errorMessage);
                    context.read<AttendanceCubit>().clearMessages();
                  } else if (state.successMessage != null) {
                    AppSnackBar.showSuccess(context, state.successMessage!);
                    context.read<AttendanceCubit>().clearMessages();
                  }
                },
              ),
            ],
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              children: [
                // 1. Employee Header Section
                _buildEmployeeHeader(),
                const SizedBox(height: 18),

                // 2. Attendance Section Title & Main + Stats Boxes
                _buildAttendanceSection(),
                const SizedBox(height: 18),

                // 3. Leave Balance Quick Card
                _buildLeaveBalanceCard(),
                const SizedBox(height: 18),

                // 4. Latest 5 Attendance Records
                _buildRecentAttendanceCard(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeHeader() {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        final profile = state.profile;
        final name = profile?.name ?? 'Arjun K C';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "Hi <Name>" title
            Text(
              'Hi $name',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${profile?.id ?? "EMP-1049"} • ${profile?.role ?? "Flutter Developer"}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAttendanceSection() {
    return BlocBuilder<AttendanceCubit, AttendanceState>(
      builder: (context, state) {
        final now = DateTime.now();
        final timeFormat = DateFormat('hh:mm a');
        final dateFormat = DateFormat('EEE, MMM d');

        final checkInStr = state.checkInRecord != null
            ? timeFormat.format(state.checkInRecord!.timestamp)
            : '--:--';
        final checkOutStr = state.checkOutRecord != null
            ? timeFormat.format(state.checkOutRecord!.timestamp)
            : '--:--';

        final currentTimeStr = timeFormat.format(now);
        final currentDateStr = dateFormat.format(now);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Attendance Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Attendance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Main Attendance Box (Matching uploaded image)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
              decoration: AppTheme.boxDecoration(radius: 20),
              child: Column(
                children: [
                  // Top Time & Date
                  Text(
                    currentTimeStr,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentDateStr,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Concentric Glowing Circular Punch Button (compact size)
                  _buildCircularPunchButton(state),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Secondary Stats Box (Check In, Check Out, Working Hrs)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: AppTheme.boxDecoration(radius: 18),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.history_rounded,
                      iconColor: AppTheme.cyanAccent,
                      time: checkInStr,
                      label: 'Check In',
                      syncStatus: state.checkInRecord?.syncStatus,
                    ),
                  ),
                  Container(height: 32, width: 1, color: Colors.white10),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.restore_rounded,
                      iconColor: AppTheme.amberAccent,
                      time: checkOutStr,
                      label: 'Check Out',
                      syncStatus: state.checkOutRecord?.syncStatus,
                    ),
                  ),
                  Container(height: 32, width: 1, color: Colors.white10),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.schedule_rounded,
                      iconColor: AppTheme.blueAccent,
                      time: _formatDuration(_elapsedDuration),
                      label: 'Working Hrs',
                      syncStatus: null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCircularPunchButton(AttendanceState state) {
    final isCheckedIn = state.todayStatus == TodayAttendanceStatus.checkedIn;
    final isCheckedOut = state.todayStatus == TodayAttendanceStatus.checkedOut;
    final isNotCheckedIn =
        state.todayStatus == TodayAttendanceStatus.notCheckedIn;

    String buttonLabel = 'PUNCH IN';
    if (isCheckedIn) buttonLabel = 'PUNCH OUT';
    if (isCheckedOut) buttonLabel = 'COMPLETED';

    final bool canPress = !state.isSubmitting && !isCheckedOut;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double buttonSize = (screenWidth * 0.32).clamp(110.0, 140.0);

    return GestureDetector(
      onTap: canPress
          ? () {
              final profile = context.read<DashboardCubit>().state.profile;
              if (isNotCheckedIn) {
                context.read<AttendanceCubit>().checkIn(
                  employeeId: profile?.id ?? 'EMP-1049',
                  officeLat: profile?.officeConfig.latitude ?? 9.9816,
                  officeLng: profile?.officeConfig.longitude ?? 76.2999,
                  radiusMeters: profile?.officeConfig.radiusMeters ?? 200.0,
                );
              } else if (isCheckedIn) {
                context.read<AttendanceCubit>().checkOut(
                  employeeId: profile?.id ?? 'EMP-1049',
                  officeLat: profile?.officeConfig.latitude ?? 9.9816,
                  officeLng: profile?.officeConfig.longitude ?? 76.2999,
                  radiusMeters: profile?.officeConfig.radiusMeters ?? 200.0,
                );
              }
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.purplePrimary.withOpacity(canPress ? 0.40 : 0.12),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(
            color: AppTheme.purplePrimary.withOpacity(0.55),
            width: 3.5,
          ),
        ),
        padding: const EdgeInsets.all(5),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.purpleDark.withOpacity(0.9),
              width: 2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isCheckedOut
                  ? [const Color(0xFF374151), const Color(0xFF1F2937)]
                  : [const Color(0xFF7C3AED), const Color(0xFF4C1D95)],
            ),
          ),
          child: Center(
            child: state.isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isCheckedOut
                            ? Icons.check_circle_outline_rounded
                            : Icons.touch_app_outlined,
                        size: 32,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        buttonLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String time,
    required String label,
    SyncStatus? syncStatus,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            time,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (syncStatus != null) ...[
          const SizedBox(height: 4),
          _buildSyncBadge(syncStatus),
        ],
      ],
    );
  }

  Widget _buildSyncBadge(SyncStatus status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case SyncStatus.synced:
        bg = const Color(0x3310B981);
        fg = const Color(0xFF34D399);
        label = 'Synced';
        icon = Icons.check;
        break;
      case SyncStatus.pending:
        bg = const Color(0x33F59E0B);
        fg = const Color(0xFFFBBF24);
        label = 'Pending';
        icon = Icons.hourglass_empty;
        break;
      case SyncStatus.rejected:
        bg = const Color(0x33EF4444);
        fg = const Color(0xFFF87171);
        label = 'Rejected';
        icon = Icons.close;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: fg),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveBalanceCard() {
    return BlocBuilder<LeaveCubit, LeaveState>(
      builder: (context, state) {
        final profile = context.read<DashboardCubit>().state.profile;
        final employeeId = profile?.id ?? 'EMP-1049';

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: AppTheme.boxDecoration(radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Leave Balances',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<LeaveCubit>(),
                            child: LeaveHistoryScreen(employeeId: employeeId),
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Manage & Apply ➔',
                      style: TextStyle(
                        color: AppTheme.purpleLight,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E143F),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.cyanAccent.withOpacity(0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Expanded(
                                child: Text(
                                  'Casual Leave',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.cyanAccent,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.beach_access_rounded,
                                size: 16,
                                color: AppTheme.cyanAccent,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${state.balance.casualLeaveRemaining} Days',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E143F),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.amberAccent.withOpacity(0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Expanded(
                                child: Text(
                                  'Sick Leave',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.amberAccent,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.medical_services_outlined,
                                size: 16,
                                color: AppTheme.amberAccent,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${state.balance.sickLeaveRemaining} Days',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentAttendanceCard() {
    return BlocBuilder<AttendanceCubit, AttendanceState>(
      builder: (context, state) {
        final timeFormat = DateFormat('MMM dd, hh:mm a');

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: AppTheme.boxDecoration(radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Recent Attendance',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (state.pendingSyncCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x33F59E0B),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.amberAccent.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        '${state.pendingSyncCount} pending',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.recentRecords.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No attendance records found',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                )
              else
                ...state.recentRecords.map((record) {
                  final isCheckIn = record.type == AttendanceType.checkIn;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E143F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: isCheckIn
                                    ? const Color(0x3322D3EE)
                                    : const Color(0x33FB923C),
                                child: Icon(
                                  isCheckIn
                                      ? Icons.login_rounded
                                      : Icons.logout_rounded,
                                  size: 14,
                                  color: isCheckIn
                                      ? AppTheme.cyanAccent
                                      : AppTheme.amberAccent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isCheckIn ? 'Check In' : 'Check Out',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      timeFormat.format(record.timestamp),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildSyncBadge(record.syncStatus),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
