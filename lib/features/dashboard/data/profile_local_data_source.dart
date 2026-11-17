import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../domain/employee_profile.dart';

class ProfileLocalDataSource {
  final AppDatabase appDatabase;

  ProfileLocalDataSource({AppDatabase? db}) : appDatabase = db ?? AppDatabase.instance;

  Future<void> saveProfile(EmployeeProfile profile) async {
    final db = await appDatabase.database;
    await db.insert(
      'employee_profile',
      profile.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<EmployeeProfile?> getProfile() async {
    final db = await appDatabase.database;
    final maps = await db.query('employee_profile', limit: 1);
    if (maps.isEmpty) return null;
    return EmployeeProfile.fromDbMap(maps.first);
  }
}
