import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import '../data/attendance_repository_impl.dart';
import '../domain/attendance_models.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/sync_queue_manager.dart';

enum TodayAttendanceStatus { notCheckedIn, checkedIn, checkedOut }

// States
class AttendanceState extends Equatable {
  final bool isLoading;
  final bool isSubmitting;
  final TodayAttendanceStatus todayStatus;
  final AttendanceRecord? checkInRecord;
  final AttendanceRecord? checkOutRecord;
  final List<AttendanceRecord> recentRecords;
  final int pendingSyncCount;
  final bool isSyncing;
  final String? errorMessage;
  final String? successMessage;
  final double? lastDistanceMeters;

  const AttendanceState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.todayStatus = TodayAttendanceStatus.notCheckedIn,
    this.checkInRecord,
    this.checkOutRecord,
    this.recentRecords = const [],
    this.pendingSyncCount = 0,
    this.isSyncing = false,
    this.errorMessage,
    this.successMessage,
    this.lastDistanceMeters,
  });

  Duration get elapsedDuration {
    if (checkInRecord == null) return Duration.zero;
    final endTime = checkOutRecord?.timestamp ?? DateTime.now();
    return endTime.difference(checkInRecord!.timestamp);
  }

  AttendanceState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    TodayAttendanceStatus? todayStatus,
    AttendanceRecord? checkInRecord,
    AttendanceRecord? checkOutRecord,
    List<AttendanceRecord>? recentRecords,
    int? pendingSyncCount,
    bool? isSyncing,
    String? errorMessage,
    String? successMessage,
    double? lastDistanceMeters,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearTodaySession = false,
  }) {
    return AttendanceState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      todayStatus: todayStatus ?? this.todayStatus,
      checkInRecord: clearTodaySession ? null : (checkInRecord ?? this.checkInRecord),
      checkOutRecord: clearTodaySession ? null : (checkOutRecord ?? this.checkOutRecord),
      recentRecords: recentRecords ?? this.recentRecords,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
      isSyncing: isSyncing ?? this.isSyncing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      lastDistanceMeters: lastDistanceMeters ?? this.lastDistanceMeters,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isSubmitting,
        todayStatus,
        checkInRecord,
        checkOutRecord,
        recentRecords,
        pendingSyncCount,
        isSyncing,
        errorMessage,
        successMessage,
        lastDistanceMeters,
      ];
}

// Cubit
class AttendanceCubit extends Cubit<AttendanceState> {
  final AttendanceRepository repository;
  final LocationService locationService;
  final SyncQueueManager syncQueueManager;

  StreamSubscription? _syncSubscription;

  AttendanceCubit({
    required this.repository,
    LocationService? locService,
    SyncQueueManager? syncManager,
  })  : locationService = locService ?? LocationService(),
        syncQueueManager = syncManager ?? repository.syncQueueManager,
        super(const AttendanceState()) {
    _initSyncListener();
  }

  void _initSyncListener() {
    _syncSubscription = syncQueueManager.statusStream.listen((update) {
      emit(state.copyWith(
        isSyncing: update.isSyncing,
        pendingSyncCount: update.pendingCount,
        successMessage: update.lastMessage,
      ));
      if (!update.isSyncing) {
        // Refresh recent records and today's session after sync completes
        loadAttendanceData(silent: true);
      }
    });
  }

  String _getTodayDate() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<void> loadAttendanceData({bool silent = false}) async {
    if (!silent) emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final todayDate = _getTodayDate();
      final session = await repository.getTodayAttendanceSession(todayDate);
      final recent = await repository.getLatestRecords(limit: 5);
      final pendingList = await repository.localDataSource.getPendingSyncRecords();

      TodayAttendanceStatus status = TodayAttendanceStatus.notCheckedIn;
      if (session['checkOut'] != null) {
        status = TodayAttendanceStatus.checkedOut;
      } else if (session['checkIn'] != null) {
        status = TodayAttendanceStatus.checkedIn;
      }

      emit(state.copyWith(
        isLoading: false,
        todayStatus: status,
        checkInRecord: session['checkIn'],
        checkOutRecord: session['checkOut'],
        recentRecords: recent,
        pendingSyncCount: pendingList.length,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load attendance: ${e.toString()}',
      ));
    }
  }

  Future<void> checkIn({
    required String employeeId,
    double officeLat = LocationService.defaultOfficeLat,
    double officeLng = LocationService.defaultOfficeLng,
    double radiusMeters = LocationService.defaultRadiusMeters,
  }) async {
    if (state.isSubmitting) return; // Prevent double taps

    emit(state.copyWith(isSubmitting: true, clearError: true, clearSuccess: true));

    // 1. Geofence & Location Validation
    final locResult = await locationService.getCurrentLocationAndValidate(
      officeLat: officeLat,
      officeLng: officeLng,
      radiusMeters: radiusMeters,
    );

    if (!locResult.isWithinGeofence) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: locResult.errorMessage ?? 'You are outside the permitted office area.',
        lastDistanceMeters: locResult.distanceMeters,
      ));
      return;
    }

    try {
      final todayDate = _getTodayDate();
      final record = await repository.recordAttendance(
        type: AttendanceType.checkIn,
        latitude: locResult.latitude,
        longitude: locResult.longitude,
        employeeId: employeeId,
        date: todayDate,
      );

      final recent = await repository.getLatestRecords(limit: 5);
      final pending = await repository.localDataSource.getPendingSyncRecords();

      emit(state.copyWith(
        isSubmitting: false,
        todayStatus: TodayAttendanceStatus.checkedIn,
        checkInRecord: record,
        recentRecords: recent,
        pendingSyncCount: pending.length,
        successMessage: 'Checked in successfully! (${record.syncStatus == SyncStatus.synced ? "Synced ✓" : "Pending Sync ⏳"})',
        lastDistanceMeters: locResult.distanceMeters,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  Future<void> checkOut({
    required String employeeId,
    double officeLat = LocationService.defaultOfficeLat,
    double officeLng = LocationService.defaultOfficeLng,
    double radiusMeters = LocationService.defaultRadiusMeters,
  }) async {
    if (state.isSubmitting) return; // Debounce taps

    if (state.todayStatus != TodayAttendanceStatus.checkedIn) {
      emit(state.copyWith(
        errorMessage: 'Check-out is only permitted after check-in.',
      ));
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true, clearSuccess: true));

    final locResult = await locationService.getCurrentLocationAndValidate(
      officeLat: officeLat,
      officeLng: officeLng,
      radiusMeters: radiusMeters,
    );

    if (!locResult.isWithinGeofence) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: locResult.errorMessage ?? 'You are outside the permitted office area.',
        lastDistanceMeters: locResult.distanceMeters,
      ));
      return;
    }

    try {
      final todayDate = _getTodayDate();
      final record = await repository.recordAttendance(
        type: AttendanceType.checkOut,
        latitude: locResult.latitude,
        longitude: locResult.longitude,
        employeeId: employeeId,
        date: todayDate,
      );

      final recent = await repository.getLatestRecords(limit: 5);
      final pending = await repository.localDataSource.getPendingSyncRecords();

      emit(state.copyWith(
        isSubmitting: false,
        todayStatus: TodayAttendanceStatus.checkedOut,
        checkOutRecord: record,
        recentRecords: recent,
        pendingSyncCount: pending.length,
        successMessage: 'Checked out successfully! (${record.syncStatus == SyncStatus.synced ? "Synced ✓" : "Pending Sync ⏳"})',
        lastDistanceMeters: locResult.distanceMeters,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  Future<void> syncNow() async {
    emit(state.copyWith(isSyncing: true, clearError: true));
    await repository.syncPendingEvents();
    await loadAttendanceData(silent: true);
  }

  Future<void> resetTodaySession() async {
    final todayDate = _getTodayDate();
    await repository.resetTodaySession(todayDate);
    emit(state.copyWith(
      todayStatus: TodayAttendanceStatus.notCheckedIn,
      clearTodaySession: true,
      clearSuccess: true,
      clearError: true,
      successMessage: "Today's attendance session has been reset. You can check in again!",
    ));
    await loadAttendanceData(silent: true);
  }

  @override
  Future<void> close() {
    _syncSubscription?.cancel();
    return super.close();
  }
}
