import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:employee_app/core/database/app_database.dart';
import 'package:employee_app/features/attendance/data/attendance_local_data_source.dart';
import 'package:employee_app/features/attendance/data/attendance_remote_data_source.dart';
import 'package:employee_app/features/attendance/data/attendance_repository_impl.dart';
import 'package:employee_app/features/attendance/domain/attendance_models.dart';
import 'package:employee_app/core/services/sync_queue_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mocktail/mocktail.dart';

class MockRemoteDataSource extends Mock implements AttendanceRemoteDataSource {}
class MockConnectivity extends Mock implements Connectivity {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database inMemoryDb;
  late AttendanceLocalDataSource localDataSource;
  late MockRemoteDataSource mockRemoteDataSource;
  late MockConnectivity mockConnectivity;
  late SyncQueueManager testSyncManager;
  late AttendanceRepository repository;

  setUp(() async {
    inMemoryDb = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await inMemoryDb.execute('''
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

    final testAppDb = AppDatabase.withDatabase(inMemoryDb);
    localDataSource = AttendanceLocalDataSource(db: testAppDb);
    mockRemoteDataSource = MockRemoteDataSource();
    mockConnectivity = MockConnectivity();

    when(() => mockConnectivity.onConnectivityChanged)
        .thenAnswer((_) => Stream.value([ConnectivityResult.wifi]));

    testSyncManager = SyncQueueManager(
      local: localDataSource,
      remote: mockRemoteDataSource,
      conn: mockConnectivity,
    );

    repository = AttendanceRepository(
      local: localDataSource,
      remote: mockRemoteDataSource,
      sync: testSyncManager,
    );
  });

  tearDown(() async {
    testSyncManager.dispose();
    await inMemoryDb.close();
  });

  group('Attendance & Idempotency Rules', () {
    test('1. Check-out without check-in is rejected', () async {
      // Expect exception when trying to check out without prior check-in for the day
      expect(
        () => repository.recordAttendance(
          type: AttendanceType.checkOut,
          latitude: 12.9716,
          longitude: 77.5946,
          employeeId: 'EMP-1049',
          date: '2026-11-17',
        ),
        throwsA(predicate((e) => e.toString().contains('Cannot check out without checking in first'))),
      );
    });

    test('2. Repeated submission or retry does not create duplicate attendance', () async {
      const clientEventId = 'fixed-uuid-12345';
      final record = AttendanceRecord(
        id: 'att_101',
        clientEventId: clientEventId,
        employeeId: 'EMP-1049',
        date: '2026-11-17',
        type: AttendanceType.checkIn,
        timestamp: DateTime(2026, 11, 17, 9, 0),
        latitude: 12.9716,
        longitude: 77.5946,
        syncStatus: SyncStatus.pending,
        createdAt: DateTime(2026, 11, 17, 9, 0),
      );

      // Save initial record
      await localDataSource.saveRecord(record);

      // Attempt to save identical record again (e.g. timeout retry or duplicate delivery)
      await localDataSource.saveRecord(record);

      // Query database: must have exactly 1 record due to primary key and unique client_event_id
      final all = await localDataSource.getAllRecords();
      expect(all.length, 1);
      expect(all.first.clientEventId, clientEventId);

      // Also verify repository blocks second check-in on the same day
      expect(
        () => repository.recordAttendance(
          type: AttendanceType.checkIn,
          latitude: 12.9716,
          longitude: 77.5946,
          employeeId: 'EMP-1049',
          date: '2026-11-17',
        ),
        throwsA(predicate((e) => e.toString().contains('Already checked in for today'))),
      );
    });

    test('3. Pending attendance survives persistence and can be synchronized in order (FIFO)', () async {
      // Insert check-in first (09:00), then check-out (18:00) with pending status
      final checkInRecord = AttendanceRecord(
        id: 'rec_1',
        clientEventId: 'uuid-check-in-001',
        employeeId: 'EMP-1049',
        date: '2026-11-17',
        type: AttendanceType.checkIn,
        timestamp: DateTime(2026, 11, 17, 9, 0, 0),
        latitude: 12.9716,
        longitude: 77.5946,
        syncStatus: SyncStatus.pending,
        createdAt: DateTime(2026, 11, 17, 9, 0, 0),
      );

      final checkOutRecord = AttendanceRecord(
        id: 'rec_2',
        clientEventId: 'uuid-check-out-002',
        employeeId: 'EMP-1049',
        date: '2026-11-17',
        type: AttendanceType.checkOut,
        timestamp: DateTime(2026, 11, 17, 18, 0, 0),
        latitude: 12.9716,
        longitude: 77.5946,
        syncStatus: SyncStatus.pending,
        createdAt: DateTime(2026, 11, 17, 18, 0, 0),
      );

      // Save records (simulating offline saves)
      await localDataSource.saveRecord(checkInRecord);
      await localDataSource.saveRecord(checkOutRecord);

      // Verify they survive persistence and are retrieved strictly in timestamp ASC order (FIFO)
      final pendingQueue = await localDataSource.getPendingSyncRecords();
      expect(pendingQueue.length, 2);
      expect(pendingQueue[0].type, AttendanceType.checkIn);
      expect(pendingQueue[1].type, AttendanceType.checkOut);

      // Setup mock remote responses
      when(() => mockRemoteDataSource.submitAttendanceEvent(checkInRecord))
          .thenAnswer((_) async => checkInRecord.copyWith(syncStatus: SyncStatus.synced));
      when(() => mockRemoteDataSource.submitAttendanceEvent(checkOutRecord))
          .thenAnswer((_) async => checkOutRecord.copyWith(syncStatus: SyncStatus.synced));

      final syncedCount = await testSyncManager.processQueue();
      expect(syncedCount, 2);

      // Verify all items are now marked 'synced' in the database
      final remainingPending = await localDataSource.getPendingSyncRecords();
      expect(remainingPending.isEmpty, isTrue);

      final allUpdated = await localDataSource.getAllRecords();
      expect(allUpdated.every((r) => r.syncStatus == SyncStatus.synced), isTrue);
    });
  });
}
