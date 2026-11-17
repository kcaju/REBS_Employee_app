import 'package:equatable/equatable.dart';

enum AttendanceType { checkIn, checkOut }

enum SyncStatus { pending, synced, rejected }

class AttendanceRecord extends Equatable {
  final String id;
  final String clientEventId;
  final String employeeId;
  final String date; // YYYY-MM-DD
  final AttendanceType type;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final SyncStatus syncStatus;
  final String? rejectionReason;
  final DateTime createdAt;

  const AttendanceRecord({
    required this.id,
    required this.clientEventId,
    required this.employeeId,
    required this.date,
    required this.type,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.syncStatus,
    this.rejectionReason,
    required this.createdAt,
  });

  AttendanceRecord copyWith({
    String? id,
    String? clientEventId,
    String? employeeId,
    String? date,
    AttendanceType? type,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    SyncStatus? syncStatus,
    String? rejectionReason,
    DateTime? createdAt,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      clientEventId: clientEventId ?? this.clientEventId,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      syncStatus: syncStatus ?? this.syncStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_event_id': clientEventId,
      'employee_id': employeeId,
      'date': date,
      'type': type == AttendanceType.checkIn ? 'CHECK_IN' : 'CHECK_OUT',
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'sync_status': syncStatus.name,
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id']?.toString() ?? '',
      clientEventId: map['client_event_id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? 'EMP-1049',
      date: map['date']?.toString() ?? '',
      type: map['type'] == 'CHECK_IN' ? AttendanceType.checkIn : AttendanceType.checkOut,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      syncStatus: SyncStatus.values.firstWhere(
        (s) => s.name == map['sync_status'],
        orElse: () => SyncStatus.synced,
      ),
      rejectionReason: map['rejection_reason'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : (map['timestamp'] != null
              ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  @override
  List<Object?> get props => [
        id,
        clientEventId,
        employeeId,
        date,
        type,
        timestamp,
        latitude,
        longitude,
        syncStatus,
        rejectionReason,
      ];
}
