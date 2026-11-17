import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/leave_models.dart';
import 'leave_bloc.dart';

class ApplyLeaveSheet extends StatefulWidget {
  final String employeeId;

  const ApplyLeaveSheet({super.key, required this.employeeId});

  @override
  State<ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends State<ApplyLeaveSheet> {
  final _formKey = GlobalKey<FormState>();
  LeaveType _selectedType = LeaveType.casual;
  late DateTime _startDate;
  late DateTime _endDate;
  final TextEditingController _reasonController = TextEditingController();

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  int get _requestedDays {
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
    if (end.isBefore(start)) return 0;
    return end.difference(start).inDays + 1;
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.isBefore(today) ? today : _startDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minDate = _startDate.isBefore(today) ? today : _startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(minDate) ? minDate : _endDate,
      firstDate: minDate,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeaveCubit, LeaveState>(
      builder: (context, state) {
        final available = _selectedType == LeaveType.casual
            ? state.balance.casualLeaveRemaining
            : state.balance.sickLeaveRemaining;

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E133D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Apply for Leave',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Leave Type Selector
                  const Text('Leave Type', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  SegmentedButton<LeaveType>(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.selected)) {
                          return AppTheme.purpleDark;
                        }
                        return const Color(0xFF281850);
                      }),
                      foregroundColor: MaterialStateProperty.all(Colors.white),
                    ),
                    segments: [
                      ButtonSegment(
                        value: LeaveType.casual,
                        label: Text('Casual (${state.balance.casualLeaveRemaining} left)'),
                        icon: const Icon(Icons.beach_access_rounded),
                      ),
                      ButtonSegment(
                        value: LeaveType.sick,
                        label: Text('Sick (${state.balance.sickLeaveRemaining} left)'),
                        icon: const Icon(Icons.medical_services_outlined),
                      ),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (set) {
                      setState(() => _selectedType = set.first);
                    },
                  ),
                  const SizedBox(height: 18),

                  // Date Pickers
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Date', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickStartDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF281850),
                                  border: Border.all(color: Colors.white24),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_dateFormat.format(_startDate), style: const TextStyle(color: Colors.white)),
                                    const Icon(Icons.calendar_month, size: 20, color: AppTheme.purpleLight),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('End Date', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickEndDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF281850),
                                  border: Border.all(color: Colors.white24),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_dateFormat.format(_endDate), style: const TextStyle(color: Colors.white)),
                                    const Icon(Icons.calendar_month, size: 20, color: AppTheme.purpleLight),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Requested Days summary banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _requestedDays > available ? const Color(0x33EF4444) : const Color(0x338B5CF6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _requestedDays > available ? Colors.redAccent : AppTheme.purpleLight.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _requestedDays > available ? Icons.error_outline : Icons.info_outline,
                          color: _requestedDays > available ? Colors.redAccent : AppTheme.cyanAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Duration: $_requestedDays calendar day(s) • Available: $available days',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _requestedDays > available ? Colors.red.shade200 : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Reason TextField
                  const Text('Reason (Min. 10 non-whitespace chars)', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _reasonController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF281850),
                      hintText: 'Describe reason for leave...',
                      hintStyle: const TextStyle(color: AppTheme.textMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.purplePrimary, width: 2),
                      ),
                    ),
                    validator: (val) {
                      final nonSpace = (val ?? '').replaceAll(RegExp(r'\s+'), '');
                      if (nonSpace.length < 10) {
                        return 'Reason must have at least 10 non-whitespace characters (${nonSpace.length}/10)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 22),

                  // Submit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: AppTheme.purplePrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final cubit = context.read<LeaveCubit>();
                        final employeeId = widget.employeeId;
                        final type = _selectedType;
                        final startDate = _startDate;
                        final endDate = _endDate;
                        final reason = _reasonController.text.trim();

                        // Close form automatically
                        Navigator.pop(context);

                        // Trigger submission
                        cubit.applyLeave(
                          employeeId: employeeId,
                          type: type,
                          startDate: startDate,
                          endDate: endDate,
                          reason: reason,
                        );
                      }
                    },
                    child: const Text('Submit Application', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
