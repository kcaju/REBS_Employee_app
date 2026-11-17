import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../data/leave_repository_impl.dart';
import '../domain/leave_models.dart';

class LeaveState extends Equatable {
  final bool isLoading;
  final bool isSubmitting;
  final LeaveBalance balance;
  final List<LeaveRequest> requests;
  final String? errorMessage;
  final String? successMessage;

  const LeaveState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.balance = const LeaveBalance(casualLeaveRemaining: 8, sickLeaveRemaining: 5),
    this.requests = const [],
    this.errorMessage,
    this.successMessage,
  });

  LeaveState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    LeaveBalance? balance,
    List<LeaveRequest>? requests,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return LeaveState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      balance: balance ?? this.balance,
      requests: requests ?? this.requests,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, isSubmitting, balance, requests, errorMessage, successMessage];
}

class LeaveCubit extends Cubit<LeaveState> {
  final LeaveRepository repository;

  LeaveCubit({required this.repository}) : super(const LeaveState());

  Future<void> loadLeaveData() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final balance = await repository.getLeaveBalance();
      final requests = await repository.getLeaveRequests();
      emit(state.copyWith(
        isLoading: false,
        balance: balance,
        requests: requests,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load leave data: ${e.toString()}',
      ));
    }
  }

  Future<bool> applyLeave({
    required String employeeId,
    required LeaveType type,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearError: true, clearSuccess: true));
    try {
      final available = type == LeaveType.casual
          ? state.balance.casualLeaveRemaining
          : state.balance.sickLeaveRemaining;

      final created = await repository.submitLeave(
        employeeId: employeeId,
        type: type,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        availableBalance: available,
      );

      // Refresh balance and list
      final newBalance = await repository.getLeaveBalance();
      final updatedRequests = [created, ...state.requests.where((r) => r.id != created.id)];

      emit(state.copyWith(
        isSubmitting: false,
        balance: newBalance,
        requests: updatedRequests,
        successMessage: 'Leave application submitted successfully!',
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
      return false;
    }
  }

  void clearMessages() {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }
}
