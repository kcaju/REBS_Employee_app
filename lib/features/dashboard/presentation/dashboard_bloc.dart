import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../data/dashboard_repository_impl.dart';
import '../domain/employee_profile.dart';

class DashboardState extends Equatable {
  final bool isLoading;
  final EmployeeProfile? profile;
  final String? errorMessage;

  const DashboardState({
    this.isLoading = false,
    this.profile,
    this.errorMessage,
  });

  DashboardState copyWith({
    bool? isLoading,
    EmployeeProfile? profile,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      profile: profile ?? this.profile,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, profile, errorMessage];
}

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository repository;

  DashboardCubit({required this.repository}) : super(const DashboardState());

  Future<void> loadDashboard({bool forceRefresh = false}) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final profile = await repository.getProfile(forceRefresh: forceRefresh);
      emit(state.copyWith(
        isLoading: false,
        profile: profile,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load profile: ${e.toString()}',
      ));
    }
  }
}
