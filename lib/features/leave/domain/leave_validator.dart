import 'leave_models.dart';

class LeaveValidationResult {
  final bool isValid;
  final String? errorMessage;

  const LeaveValidationResult({required this.isValid, this.errorMessage});

  factory LeaveValidationResult.valid() => const LeaveValidationResult(isValid: true);
  factory LeaveValidationResult.invalid(String message) => LeaveValidationResult(isValid: false, errorMessage: message);
}

class LeaveValidator {
  static LeaveValidationResult validate({
    required LeaveType leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required int availableBalance,
    required List<LeaveRequest> existingRequests,
    DateTime? currentCompanyDate,
  }) {
    final companyDate = currentCompanyDate ?? DateTime.now();
    final today = DateTime(companyDate.year, companyDate.month, companyDate.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    // 1. Start date cannot be before current company date
    if (start.isBefore(today)) {
      return LeaveValidationResult.invalid(
        'Start date cannot be in the past. Current company date is ${today.toIso8601String().substring(0, 10)}.',
      );
    }

    // 2. End date cannot be before start date
    if (end.isBefore(start)) {
      return LeaveValidationResult.invalid('End date cannot be before start date.');
    }

    // 3. Reason must contain at least 10 non-whitespace characters
    final nonWhitespaceChars = reason.replaceAll(RegExp(r'\s+'), '');
    if (nonWhitespaceChars.length < 10) {
      return LeaveValidationResult.invalid(
        'Reason must contain at least 10 non-whitespace characters (currently ${nonWhitespaceChars.length}).',
      );
    }

    // 4. Requested days cannot exceed available balance
    final daysRequested = end.difference(start).inDays + 1;
    if (daysRequested > availableBalance) {
      final typeLabel = leaveType == LeaveType.casual ? 'Casual' : 'Sick';
      return LeaveValidationResult.invalid(
        'Requested days ($daysRequested) exceed available $typeLabel balance ($availableBalance).',
      );
    }

    // 5. Overlap detection with existing Pending or Approved requests
    for (final req in existingRequests) {
      if (req.status == LeaveStatus.approved || req.status == LeaveStatus.pending) {
        final reqStart = DateTime(req.startDate.year, req.startDate.month, req.startDate.day);
        final reqEnd = DateTime(req.endDate.year, req.endDate.month, req.endDate.day);

        // Check date overlap: (start <= reqEnd) && (end >= reqStart)
        if (!start.isAfter(reqEnd) && !end.isBefore(reqStart)) {
          final statusStr = req.status.name[0].toUpperCase() + req.status.name.substring(1);
          return LeaveValidationResult.invalid(
            'Requested dates overlap with an existing $statusStr request (${req.startDate.toIso8601String().substring(0, 10)} to ${req.endDate.toIso8601String().substring(0, 10)}).',
          );
        }
      }
    }

    return LeaveValidationResult.valid();
  }
}
