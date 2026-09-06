import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/features/dashboard/models/dashboard_data.dart';
import 'package:jonkstore/repositories/dashboard_repository.dart';
import 'package:jonkstore/providers/repository_providers.dart';

/// State representing the data and status of the Dashboard.
class DashboardState {
  final bool isLoading;
  final String? errorMessage;
  final DashboardData? data;

  DashboardState({
    this.isLoading = false,
    this.errorMessage,
    this.data,
  });

  DashboardState copyWith({
    bool? isLoading,
    String? errorMessage,
    DashboardData? data,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      data: data ?? this.data,
    );
  }
}

/// Controller for the Dashboard screen, managing real business metrics.
class DashboardController extends StateNotifier<DashboardState> {
  final DashboardRepository _repository;

  DashboardController(this._repository) : super(DashboardState()) {
    // Automatically load data for 'today' on initialization
    loadDashboardData();
  }

  /// Fetches the latest dashboard data from the SQLite repository.
  Future<void> loadDashboardData({String period = 'today'}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    final result = await _repository.getDashboardData(period);
    
    result.fold(
      (data) => state = state.copyWith(isLoading: false, data: data),
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }
}

/// Provider for the [DashboardController].
final dashboardControllerProvider = StateNotifierProvider<DashboardController, DashboardState>((ref) {
  final repository = ref.watch(dashboardRepositoryProvider);
  return DashboardController(repository);
});
