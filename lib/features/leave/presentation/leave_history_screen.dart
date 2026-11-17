import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../domain/leave_models.dart';
import 'leave_bloc.dart';
import 'apply_leave_sheet.dart';

class LeaveHistoryScreen extends StatelessWidget {
  final String employeeId;

  const LeaveHistoryScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Leave Management', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppTheme.purplePrimary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Apply Leave', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: const Color(0xFF1E133D),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => BlocProvider.value(
                value: context.read<LeaveCubit>(),
                child: ApplyLeaveSheet(employeeId: employeeId),
              ),
            );
          },
        ),
        body: BlocConsumer<LeaveCubit, LeaveState>(
          listenWhen: (previous, current) =>
              (previous.errorMessage != current.errorMessage && current.errorMessage != null) ||
              (previous.successMessage != current.successMessage && current.successMessage != null),
          listener: (context, state) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(child: Text(state.errorMessage!)),
                    ],
                  ),
                  backgroundColor: Colors.red.shade700,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                ),
              );
            } else if (state.successMessage != null) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(child: Text(state.successMessage!)),
                    ],
                  ),
                  backgroundColor: Colors.green.shade700,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
          builder: (context, state) {
            if (state.isLoading && state.requests.isEmpty) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.purplePrimary));
            }

            return Column(
              children: [
                if (state.isSubmitting)
                  const LinearProgressIndicator(color: AppTheme.purplePrimary, backgroundColor: Colors.white12),
                Expanded(
                  child: RefreshIndicator(
                    color: AppTheme.purplePrimary,
                    onRefresh: () => context.read<LeaveCubit>().loadLeaveData(),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Leave Balances Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildBalanceCard(
                                context,
                                title: 'Casual Leave',
                                balance: state.balance.casualLeaveRemaining,
                                color: AppTheme.cyanAccent,
                                icon: Icons.beach_access_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildBalanceCard(
                                context,
                                title: 'Sick Leave',
                                balance: state.balance.sickLeaveRemaining,
                                color: AppTheme.amberAccent,
                                icon: Icons.medical_services_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Application History',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                        ),
                        const SizedBox(height: 12),

                        if (state.requests.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: AppTheme.boxDecoration(radius: 20),
                            alignment: Alignment.center,
                            child: Column(
                              children: const [
                                Icon(Icons.calendar_today_outlined, size: 48, color: AppTheme.textMuted),
                                SizedBox(height: 12),
                                Text(
                                  'No leave applications yet',
                                  style: TextStyle(color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          )
                        else
                          ...state.requests.map((req) => _buildLeaveItem(context, req)),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBalanceCard(
    BuildContext context, {
    required String title,
    required int balance,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.boxDecoration(
        radius: 20,
        borderColor: color.withOpacity(0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$balance Days',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text('Available Balance', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildLeaveItem(BuildContext context, LeaveRequest request) {
    Color badgeBg;
    Color badgeTextColor;
    IconData statusIcon;

    switch (request.status) {
      case LeaveStatus.approved:
        badgeBg = const Color(0x3310B981);
        badgeTextColor = const Color(0xFF34D399);
        statusIcon = Icons.check_circle_outline;
        break;
      case LeaveStatus.rejected:
        badgeBg = const Color(0x33EF4444);
        badgeTextColor = const Color(0xFFF87171);
        statusIcon = Icons.cancel_outlined;
        break;
      case LeaveStatus.pending:
        badgeBg = const Color(0x33F59E0B);
        badgeTextColor = const Color(0xFFFBBF24);
        statusIcon = Icons.access_time;
        break;
    }

    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.boxDecoration(radius: 18),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    request.leaveType == LeaveType.casual ? Icons.beach_access_rounded : Icons.medical_services_outlined,
                    size: 18,
                    color: AppTheme.purpleLight,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${request.leaveType == LeaveType.casual ? "Casual" : "Sick"} Leave • ${request.daysCount} Day(s)',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeTextColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: badgeTextColor),
                    const SizedBox(width: 4),
                    Text(
                      request.status.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.date_range_rounded, size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                '${dateFormat.format(request.startDate)}  ➔  ${dateFormat.format(request.endDate)}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            request.reason,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
