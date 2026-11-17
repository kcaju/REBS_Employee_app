import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
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
          _elapsedDuration = DateTime.now().difference(attendanceState.checkInRecord!.timestamp);
        });
      } else if (attendanceState.todayStatus == TodayAttendanceStatus.checkedOut &&
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('REBS Workspace', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync),
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
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
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
              icon: const Icon(Icons.settings_outlined),
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
              listener: (context, state) {
                if (state.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.errorMessage!),
                      backgroundColor: Colors.red.shade700,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
                if (state.successMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.successMessage!),
                      backgroundColor: Colors.green.shade700,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
          ],
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Employee Header Card
              _buildEmployeeHeader(),
              const SizedBox(height: 16),

              // 2. Today's Attendance & Action Card
              _buildTodayAttendanceCard(),
              const SizedBox(height: 16),

              // 3. Leave Balance Quick Card
              _buildLeaveBalanceCard(),
              const SizedBox(height: 16),

              // 4. Latest 5 Attendance Records
              _buildRecentAttendanceCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeHeader() {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        final profile = state.profile;
        if (state.isLoading && profile == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.indigo.shade100,
                  child: Text(
                    (profile?.name.isNotEmpty ?? false) ? profile!.name[0] : 'E',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.name ?? 'Alex Morgan',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${profile?.id ?? "EMP-1049"} • ${profile?.department ?? "Engineering"}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.indigo.shade400),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              profile?.officeConfig.officeName ?? 'Bengaluru HQ (200m Geofence)',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTodayAttendanceCard() {
    return BlocBuilder<AttendanceCubit, AttendanceState>(
      builder: (context, state) {
        final timeFormat = DateFormat('hh:mm a');

        Color statusColor;
        String statusText;
        IconData statusIcon;

        switch (state.todayStatus) {
          case TodayAttendanceStatus.checkedIn:
            statusColor = Colors.green;
            statusText = 'Checked In';
            statusIcon = Icons.login_rounded;
            break;
          case TodayAttendanceStatus.checkedOut:
            statusColor = Colors.blueGrey;
            statusText = 'Checked Out';
            statusIcon = Icons.logout_rounded;
            break;
          case TodayAttendanceStatus.notCheckedIn:
            statusColor = Colors.orange;
            statusText = 'Not Checked In';
            statusIcon = Icons.schedule;
            break;
        }

        final checkInStr = state.checkInRecord != null
            ? timeFormat.format(state.checkInRecord!.timestamp)
            : '--:--';
        final checkOutStr = state.checkOutRecord != null
            ? timeFormat.format(state.checkOutRecord!.timestamp)
            : '--:--';

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "Today's Attendance",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Timing & Duration row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol('Check-In', checkInStr, state.checkInRecord?.syncStatus),
                    _buildStatCol('Check-Out', checkOutStr, state.checkOutRecord?.syncStatus),
                    _buildStatCol('Working Hours', _formatDuration(_elapsedDuration), null),
                  ],
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.login),
                        label: const Text('Check In'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        // Only enabled if Not Checked In and not currently submitting
                        onPressed: (state.todayStatus == TodayAttendanceStatus.notCheckedIn && !state.isSubmitting)
                            ? () {
                                final profile = context.read<DashboardCubit>().state.profile;
                                context.read<AttendanceCubit>().checkIn(
                                      employeeId: profile?.id ?? 'EMP-1049',
                                      officeLat: profile?.officeConfig.latitude ?? 12.9716,
                                      officeLng: profile?.officeConfig.longitude ?? 77.5946,
                                      radiusMeters: profile?.officeConfig.radiusMeters ?? 200.0,
                                    );
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text('Check Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        // Check out permitted only after check in
                        onPressed: (state.todayStatus == TodayAttendanceStatus.checkedIn && !state.isSubmitting)
                            ? () {
                                final profile = context.read<DashboardCubit>().state.profile;
                                context.read<AttendanceCubit>().checkOut(
                                      employeeId: profile?.id ?? 'EMP-1049',
                                      officeLat: profile?.officeConfig.latitude ?? 12.9716,
                                      officeLng: profile?.officeConfig.longitude ?? 77.5946,
                                      radiusMeters: profile?.officeConfig.radiusMeters ?? 200.0,
                                    );
                              }
                            : null,
                      ),
                    ),
                  ],
                ),

                if (state.isSubmitting)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Verifying location and recording event...', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCol(String label, String value, SyncStatus? syncStatus) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        if (syncStatus != null) ...[
          const SizedBox(height: 2),
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
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        label = 'Synced';
        icon = Icons.check;
        break;
      case SyncStatus.pending:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        label = 'Pending Sync';
        icon = Icons.hourglass_empty;
        break;
      case SyncStatus.rejected:
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        label = 'Rejected';
        icon = Icons.close;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg),
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

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Leave Balances',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                      child: const Text('Manage & Apply ➔'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Casual Leave', style: TextStyle(fontSize: 12, color: Colors.blue)),
                            const SizedBox(height: 4),
                            Text(
                              '${state.balance.casualLeaveRemaining} Days',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Sick Leave', style: TextStyle(fontSize: 12, color: Colors.teal)),
                            const SizedBox(height: 4),
                            Text(
                              '${state.balance.sickLeaveRemaining} Days',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentAttendanceCard() {
    return BlocBuilder<AttendanceCubit, AttendanceState>(
      builder: (context, state) {
        final timeFormat = DateFormat('MMM dd, hh:mm a');

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Recent Attendance (Latest 5)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (state.pendingSyncCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${state.pendingSyncCount} pending sync',
                          style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (state.recentRecords.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No attendance records found',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  )
                else
                  ...state.recentRecords.map((record) {
                    final isCheckIn = record.type == AttendanceType.checkIn;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isCheckIn ? Colors.green.shade100 : Colors.red.shade100,
                                  child: Icon(
                                    isCheckIn ? Icons.login : Icons.logout,
                                    size: 14,
                                    color: isCheckIn ? Colors.green.shade800 : Colors.red.shade800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isCheckIn ? 'Check In' : 'Check Out',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        timeFormat.format(record.timestamp),
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
          ),
        );
      },
    );
  }
}
