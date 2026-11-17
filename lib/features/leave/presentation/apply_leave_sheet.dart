import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
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

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Apply for Leave',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Leave Type Selector
                  const Text('Leave Type', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  SegmentedButton<LeaveType>(
                    segments: [
                      ButtonSegment(
                        value: LeaveType.casual,
                        label: Text('Casual (${state.balance.casualLeaveRemaining} left)'),
                        icon: const Icon(Icons.beach_access),
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
                  const SizedBox(height: 16),

                  // Date Pickers
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Date', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickStartDate,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_dateFormat.format(_startDate)),
                                    const Icon(Icons.calendar_month, size: 20),
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
                            const Text('End Date', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickEndDate,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_dateFormat.format(_endDate)),
                                    const Icon(Icons.calendar_month, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Requested Days summary banner
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _requestedDays > available ? Colors.red.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _requestedDays > available ? Colors.red.shade300 : Colors.blue.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _requestedDays > available ? Icons.error_outline : Icons.info_outline,
                          color: _requestedDays > available ? Colors.red.shade700 : Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Duration: $_requestedDays calendar day(s) • Available: $available days',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _requestedDays > available ? Colors.red.shade900 : Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reason TextField
                  const Text('Reason (Min. 10 non-whitespace chars)', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Describe reason for leave...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      final nonSpace = (val ?? '').replaceAll(RegExp(r'\s+'), '');
                      if (nonSpace.length < 10) {
                        return 'Reason must have at least 10 non-whitespace characters (${nonSpace.length}/10)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
