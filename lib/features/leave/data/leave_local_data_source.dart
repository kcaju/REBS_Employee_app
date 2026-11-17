import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../domain/leave_models.dart';

class LeaveLocalDataSource {
  final AppDatabase appDatabase;

  LeaveLocalDataSource({AppDatabase? db}) : appDatabase = db ?? AppDatabase.instance;

  static final List<LeaveRequest> initialSeedRequests = [
    LeaveRequest(
      id: 'LR-001',
      employeeId: 'EMP-1049',
      leaveType: LeaveType.casual,
      startDate: DateTime(2026, 11, 1),
      endDate: DateTime(2026, 11, 2),
      reason: 'Family gathering out of station',
      status: LeaveStatus.approved,
      createdAt: DateTime.parse('2026-10-25T10:00:00Z'),
    ),
    LeaveRequest(
      id: 'LR-002',
      employeeId: 'EMP-1049',
      leaveType: LeaveType.sick,
      startDate: DateTime(2026, 11, 5),
      endDate: DateTime(2026, 11, 6),
      reason: 'Viral fever and medical rest',
      status: LeaveStatus.rejected,
      createdAt: DateTime.parse('2026-10-28T14:30:00Z'),
    ),
  ];

  Future<void> ensureInitialSeeds() async {
    final db = await appDatabase.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM leave_requests'),
    ) ?? 0;
    if (count == 0) {
      await saveLeaveRequests(initialSeedRequests);
    }
  }

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
    var maps = await db.query(
      'leave_requests',
      orderBy: 'created_at DESC',
    );
    if (maps.isEmpty) {
      await ensureInitialSeeds();
      maps = await db.query(
        'leave_requests',
        orderBy: 'created_at DESC',
      );
    }
    return maps.map((m) => LeaveRequest.fromMap(m)).toList();
  }

  Future<void> clearAll() async {
    final db = await appDatabase.database;
    await db.delete('leave_requests');
  }
}
