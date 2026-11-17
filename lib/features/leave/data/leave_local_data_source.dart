import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../domain/leave_models.dart';

class LeaveLocalDataSource {
  final AppDatabase appDatabase;

  LeaveLocalDataSource({AppDatabase? db}) : appDatabase = db ?? AppDatabase.instance;

  Future<void> saveLeaveRequests(List<LeaveRequest> requests) async {
    final db = await appDatabase.database;
    final batch = db.batch();
    for (final req in requests) {
      batch.insert(
        'leave_requests',
        req.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> saveSingleRequest(LeaveRequest request) async {
    final db = await appDatabase.database;
    await db.insert(
      'leave_requests',
      request.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LeaveRequest>> getLeaveRequests() async {
    final db = await appDatabase.database;
    final maps = await db.query(
      'leave_requests',
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => LeaveRequest.fromMap(m)).toList();
  }

  Future<void> clearAll() async {
    final db = await appDatabase.database;
    await db.delete('leave_requests');
  }
}
