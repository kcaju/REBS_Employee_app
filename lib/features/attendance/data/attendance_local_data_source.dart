import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../domain/attendance_models.dart';

class AttendanceLocalDataSource {
  final AppDatabase appDatabase;

  AttendanceLocalDataSource({AppDatabase? db}) : appDatabase = db ?? AppDatabase.instance;

  Future<void> saveRecord(AttendanceRecord record) async {
    final db = await appDatabase.database;
    await db.insert(
      'attendance_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSyncStatus(
    String clientEventId,
    SyncStatus status, {
    String? rejectionReason,
  }) async {
    final db = await appDatabase.database;
    await db.update(
      'attendance_records',
      {
        'sync_status': status.name,
        'rejection_reason': rejectionReason,
      },
      where: 'client_event_id = ?',
      whereArgs: [clientEventId],
    );
  }

  /// Strictly ordered by timestamp ASC to preserve FIFO check-in then check-out
  Future<List<AttendanceRecord>> getPendingSyncRecords() async {
    final db = await appDatabase.database;
    final maps = await db.query(
      'attendance_records',
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pending.name],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => AttendanceRecord.fromMap(m)).toList();
  }

  Future<List<AttendanceRecord>> getLatestRecords({int limit = 5}) async {
    final db = await appDatabase.database;
    final maps = await db.query(
      'attendance_records',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map((m) => AttendanceRecord.fromMap(m)).toList();
  }

  Future<List<AttendanceRecord>> getRecordsForDate(String date) async {
    final db = await appDatabase.database;
    final maps = await db.query(
      'attendance_records',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => AttendanceRecord.fromMap(m)).toList();
  }

  Future<List<AttendanceRecord>> getAllRecords() async {
    final db = await appDatabase.database;
    final maps = await db.query(
      'attendance_records',
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => AttendanceRecord.fromMap(m)).toList();
  }

  Future<void> clearAll() async {
    final db = await appDatabase.database;
    await db.delete('attendance_records');
  }
}
