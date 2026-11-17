import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../domain/attendance_models.dart';

class AttendanceRemoteDataSource {
  final ApiClient apiClient;

  AttendanceRemoteDataSource({ApiClient? client}) : apiClient = client ?? ApiClient();

  Future<List<AttendanceRecord>> fetchAttendanceHistory({String? month}) async {
    final response = await apiClient.dio.get(
      '/attendance',
      queryParameters: month != null ? {'month': month} : null,
    );
    final data = response.data as Map<String, dynamic>;
    final records = data['records'] as List<dynamic>;
    return records.map((r) => AttendanceRecord.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<AttendanceRecord> submitAttendanceEvent(AttendanceRecord record) async {
    final response = await apiClient.dio.post(
      '/attendance/events',
      data: {
        'client_event_id': record.clientEventId,
        'employee_id': record.employeeId,
        'date': record.date,
        'type': record.type == AttendanceType.checkIn ? 'CHECK_IN' : 'CHECK_OUT',
        'timestamp': record.timestamp.toIso8601String(),
        'latitude': record.latitude,
        'longitude': record.longitude,
      },
      options: Options(
        headers: {
          'X-Idempotency-Key': record.clientEventId,
        },
      ),
    );

    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('event')) {
      return AttendanceRecord.fromMap(data['event'] as Map<String, dynamic>);
    }
    return record.copyWith(syncStatus: SyncStatus.synced);
  }
}
