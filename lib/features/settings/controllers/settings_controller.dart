import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/core/domain/models/settings.dart';
import 'package:jonkstore/repositories/settings_repository.dart';
import 'package:jonkstore/providers/repository_providers.dart';
import 'package:jonkstore/features/dashboard/providers/dashboard_providers.dart';

class SettingsState {
  final bool isLoading;
  final String? errorMessage;
  final Settings? settings;
  final bool isSuccess;

  SettingsState({
    this.isLoading = false,
    this.errorMessage,
    this.settings,
    this.isSuccess = false,
  });

  SettingsState copyWith({
    bool? isLoading,
    String? errorMessage,
    Settings? settings,
    bool? isSuccess,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      settings: settings ?? this.settings,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class SettingsController extends StateNotifier<SettingsState> {
  final SettingsRepository _repository;
  final Ref _ref;

  SettingsController(this._repository, this._ref) : super(SettingsState());

  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    final business = await _ref.read(currentBusinessProvider.future);
    if (business == null) {
      state = state.copyWith(isLoading: false, errorMessage: 'Business not found');
      return;
    }

    final result = await _repository.getSettings(business.id);
    result.fold(
      (settings) => state = state.copyWith(isLoading: false, settings: settings),
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  Future<void> updateSettings(Settings settings) async {
    state = state.copyWith(isLoading: true, errorMessage: null, isSuccess: false);
    
    final result = await _repository.update(settings);
    result.fold(
      (updated) => state = state.copyWith(isLoading: false, settings: updated, isSuccess: true),
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }
}

final settingsControllerProvider = StateNotifierProvider<SettingsController, SettingsState>((ref) {
  return SettingsController(ref.watch(settingsRepositoryProvider), ref);
});
