import 'package:flutter_test/flutter_test.dart';
import 'package:employee_app/features/leave/domain/leave_models.dart';
import 'package:employee_app/features/leave/domain/leave_validator.dart';

void main() {
  group('LeaveValidator Tests', () {
    final fixedCompanyDate = DateTime(2026, 11, 17);

    final existingApprovedRequest = LeaveRequest(
      id: 'LR-001',
      employeeId: 'EMP-1049',
      leaveType: LeaveType.casual,
      startDate: DateTime(2026, 11, 20),
      endDate: DateTime(2026, 11, 22),
      reason: 'Existing approved holiday trip',
      status: LeaveStatus.approved,
      createdAt: DateTime(2026, 11, 10),
    );

    test('Overlapping leave dates are rejected (Requirement 4)', () {
      // Trying to request 2026-11-21 to 2026-11-23 which overlaps 2026-11-20 to 2026-11-22
      final result = LeaveValidator.validate(
        leaveType: LeaveType.casual,
        startDate: DateTime(2026, 11, 21),
        endDate: DateTime(2026, 11, 23),
        reason: 'Valid reason with plenty of characters',
        availableBalance: 5,
        existingRequests: [existingApprovedRequest],
        currentCompanyDate: fixedCompanyDate,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('overlap with an existing Approved request'));
    });

    test('Non-overlapping leave dates are accepted', () {
      final result = LeaveValidator.validate(
        leaveType: LeaveType.casual,
        startDate: DateTime(2026, 11, 25),
        endDate: DateTime(2026, 11, 26),
        reason: 'Attending wedding reception ceremony',
        availableBalance: 5,
        existingRequests: [existingApprovedRequest],
        currentCompanyDate: fixedCompanyDate,
      );

      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('Start date before current company date is rejected', () {
      final result = LeaveValidator.validate(
        leaveType: LeaveType.casual,
        startDate: DateTime(2026, 11, 15), // Past date
        endDate: DateTime(2026, 11, 18),
        reason: 'Valid length reason text here',
        availableBalance: 5,
        existingRequests: [],
        currentCompanyDate: fixedCompanyDate,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('cannot be in the past'));
    });

    test('End date before start date is rejected', () {
      final result = LeaveValidator.validate(
        leaveType: LeaveType.sick,
        startDate: DateTime(2026, 11, 20),
        endDate: DateTime(2026, 11, 18),
        reason: 'Valid length reason text here',
        availableBalance: 5,
        existingRequests: [],
        currentCompanyDate: fixedCompanyDate,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('End date cannot be before start date'));
    });

    test('Reason with less than 10 non-whitespace characters is rejected', () {
      final result = LeaveValidator.validate(
        leaveType: LeaveType.sick,
        startDate: DateTime(2026, 11, 20),
        endDate: DateTime(2026, 11, 20),
        reason: ' sick ', // only 4 characters
        availableBalance: 5,
        existingRequests: [],
        currentCompanyDate: fixedCompanyDate,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Reason must contain at least 10 non-whitespace characters'));
    });

    test('Requested days exceeding available balance is rejected', () {
      final result = LeaveValidator.validate(
        leaveType: LeaveType.sick,
        startDate: DateTime(2026, 11, 20),
        endDate: DateTime(2026, 11, 25), // 6 days
        reason: 'Suffering from high fever and weakness',
        availableBalance: 3, // only 3 available
        existingRequests: [],
        currentCompanyDate: fixedCompanyDate,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('exceed available Sick balance'));
    });
  });
}
