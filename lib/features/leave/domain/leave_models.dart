import 'package:equatable/equatable.dart';

enum LeaveType { casual, sick }

enum LeaveStatus { pending, approved, rejected }

class LeaveRequest extends Equatable {
  final String id;
  final String employeeId;
  final LeaveType leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final LeaveStatus status;
  final DateTime createdAt;

  const LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  int get daysCount {
    return endDate.difference(startDate).inDays + 1;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'leave_type': leaveType == LeaveType.casual ? 'Casual' : 'Sick',
      'start_date': startDate.toIso8601String().substring(0, 10),
      'end_date': endDate.toIso8601String().substring(0, 10),
      'reason': reason,
      'status': status.name[0].toUpperCase() + status.name.substring(1),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    return LeaveRequest(
      id: map['id'] as String,
      employeeId: map['employee_id'] as String,
      leaveType: (map['leave_type'] as String).toLowerCase() == 'casual'
          ? LeaveType.casual
          : LeaveType.sick,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      reason: map['reason'] as String,
      status: _parseStatus(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static LeaveStatus _parseStatus(String statusStr) {
    switch (statusStr.toLowerCase()) {
      case 'approved':
        return LeaveStatus.approved;
      case 'rejected':
        return LeaveStatus.rejected;
      case 'pending':
      default:
        return LeaveStatus.pending;
    }
  }

  @override
  List<Object?> get props => [id, employeeId, leaveType, startDate, endDate, reason, status, createdAt];
}

class LeaveBalance extends Equatable {
  final int casualLeaveRemaining;
  final int sickLeaveRemaining;

  const LeaveBalance({
    required this.casualLeaveRemaining,
    required this.sickLeaveRemaining,
  });

  @override
  List<Object?> get props => [casualLeaveRemaining, sickLeaveRemaining];
}
