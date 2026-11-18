import 'package:equatable/equatable.dart';

class OfficeConfig extends Equatable {
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String officeName;
  final String timezone;

  const OfficeConfig({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.officeName,
    required this.timezone,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'allowed_radius': radiusMeters,
      'office_name': officeName,
      'timezone': timezone,
    };
  }

  factory OfficeConfig.fromMap(Map<String, dynamic> map) {
    return OfficeConfig(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radiusMeters: ((map['allowed_radius'] ?? map['radius_meters']) as num?)?.toDouble() ?? 200.0,
      officeName: map['office_name'] as String? ?? 'REBS Office',
      timezone: map['timezone'] as String? ?? 'Asia/Kolkata',
    );
  }

  @override
  List<Object?> get props => [latitude, longitude, radiusMeters, officeName, timezone];
}

class EmployeeProfile extends Equatable {
  final String id;
  final String name;
  final String email;
  final String department;
  final String role;
  final int casualLeaveRemaining;
  final int sickLeaveRemaining;
  final OfficeConfig officeConfig;

  const EmployeeProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
    required this.role,
    required this.casualLeaveRemaining,
    required this.sickLeaveRemaining,
    required this.officeConfig,
  });

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'department': department,
      'role': role,
      'casual_leave_remaining': casualLeaveRemaining,
      'sick_leave_remaining': sickLeaveRemaining,
      'office_lat': officeConfig.latitude,
      'office_lng': officeConfig.longitude,
      'geofence_radius': officeConfig.radiusMeters,
      'office_name': officeConfig.officeName,
      'timezone': officeConfig.timezone,
      'cached_at': DateTime.now().toIso8601String(),
    };
  }

  factory EmployeeProfile.fromDbMap(Map<String, dynamic> map) {
    return EmployeeProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      department: map['department'] as String,
      role: map['role'] as String,
      casualLeaveRemaining: map['casual_leave_remaining'] as int,
      sickLeaveRemaining: map['sick_leave_remaining'] as int,
      officeConfig: OfficeConfig(
        latitude: (map['office_lat'] as num).toDouble(),
        longitude: (map['office_lng'] as num).toDouble(),
        radiusMeters: (map['geofence_radius'] as num).toDouble(),
        officeName: map['office_name'] as String,
        timezone: map['timezone'] as String,
      ),
    );
  }

  factory EmployeeProfile.fromJson(Map<String, dynamic> json, {int casualLeave = 8, int sickLeave = 5}) {
    return EmployeeProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      department: json['department'] as String,
      role: json['role'] as String,
      casualLeaveRemaining: casualLeave,
      sickLeaveRemaining: sickLeave,
      officeConfig: OfficeConfig.fromMap(json['office_config'] as Map<String, dynamic>),
    );
  }

  EmployeeProfile copyWith({
    int? casualLeaveRemaining,
    int? sickLeaveRemaining,
    OfficeConfig? officeConfig,
  }) {
    return EmployeeProfile(
      id: id,
      name: name,
      email: email,
      department: department,
      role: role,
      casualLeaveRemaining: casualLeaveRemaining ?? this.casualLeaveRemaining,
      sickLeaveRemaining: sickLeaveRemaining ?? this.sickLeaveRemaining,
      officeConfig: officeConfig ?? this.officeConfig,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        department,
        role,
        casualLeaveRemaining,
        sickLeaveRemaining,
        officeConfig,
      ];
}
