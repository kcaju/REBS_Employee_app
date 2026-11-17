import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../domain/leave_models.dart';
import 'leave_bloc.dart';
import 'apply_leave_sheet.dart';

class LeaveHistoryScreen extends StatelessWidget {
  final String employeeId;

  const LeaveHistoryScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Management'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Apply Leave'),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => BlocProvider.value(
              value: context.read<LeaveCubit>(),
              child: ApplyLeaveSheet(employeeId: employeeId),
            ),
          );
        },
      ),
      body: BlocBuilder<LeaveCubit, LeaveState>(
        builder: (context, state) {
          if (state.isLoading && state.requests.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
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
                        color: Colors.blue.shade700,
                        icon: Icons.beach_access,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBalanceCard(
                        context,
                        title: 'Sick Leave',
                        balance: state.balance.sickLeaveRemaining,
                        color: Colors.teal.shade700,
                        icon: Icons.medical_services_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Text(
                  'Application History',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),

                if (state.requests.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No leave applications yet',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                else
                  ...state.requests.map((req) => _buildLeaveItem(context, req)),
                const SizedBox(height: 60),
              ],
            ),
          );
        },
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
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$balance Days',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          const Text('Available Balance', style: TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildLeaveItem(BuildContext context, LeaveRequest request) {
    Color badgeColor;
    Color textColor;
    IconData statusIcon;

    switch (request.status) {
      case LeaveStatus.approved:
        badgeColor = Colors.green.shade50;
        textColor = Colors.green.shade800;
        statusIcon = Icons.check_circle_outline;
        break;
      case LeaveStatus.rejected:
        badgeColor = Colors.red.shade50;
        textColor = Colors.red.shade800;
        statusIcon = Icons.cancel_outlined;
        break;
      case LeaveStatus.pending:
        badgeColor = Colors.amber.shade50;
        textColor = Colors.amber.shade900;
        statusIcon = Icons.access_time;
        break;
    }

    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      request.leaveType == LeaveType.casual ? Icons.beach_access : Icons.medical_services_outlined,
                      size: 18,
                      color: Colors.indigo,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${request.leaveType == LeaveType.casual ? "Casual" : "Sick"} Leave • ${request.daysCount} Day(s)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: textColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: textColor),
                      const SizedBox(width: 4),
                      Text(
                        request.status.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${dateFormat.format(request.startDate)}  ➔  ${dateFormat.format(request.endDate)}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              request.reason,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
