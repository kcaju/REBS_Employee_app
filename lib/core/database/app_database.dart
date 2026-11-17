import 'dart:async';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  // For testing or custom injection
  AppDatabase.withDatabase(Database db) {
    _database = db;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('rebs_employee_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Attendance Records & Sync Queue
    await db.execute('''
      CREATE TABLE attendance_records (
        id TEXT PRIMARY KEY,
        client_event_id TEXT UNIQUE NOT NULL,
        employee_id TEXT NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        sync_status TEXT NOT NULL,
        rejection_reason TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Index for quick ordering of sync queue FIFO and date lookup
    await db.execute('''
      CREATE INDEX idx_attendance_sync ON attendance_records (sync_status, timestamp ASC)
    ''');
    await db.execute('''
      CREATE INDEX idx_attendance_date ON attendance_records (date, type)
    ''');

    // 2. Leave Requests Cache
    await db.execute('''
      CREATE TABLE leave_requests (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        leave_type TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        reason TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 3. Employee Profile & Config Cache
    await db.execute('''
      CREATE TABLE employee_profile (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        department TEXT NOT NULL,
        role TEXT NOT NULL,
        casual_leave_remaining INTEGER NOT NULL,
        sick_leave_remaining INTEGER NOT NULL,
        office_lat REAL NOT NULL,
        office_lng REAL NOT NULL,
        geofence_radius REAL NOT NULL,
        office_name TEXT NOT NULL,
        timezone TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
