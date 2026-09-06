import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/core/domain/models/ai_recommendation.dart';
import 'package:jonkstore/repositories/ai_repository.dart';
import 'package:jonkstore/providers/repository_providers.dart';
import 'package:jonkstore/features/dashboard/providers/dashboard_providers.dart';

class AIState {
  final bool isLoading;
  final String? errorMessage;
  final List<AIRecommendation> recommendations;

  AIState({
    this.isLoading = false,
    this.errorMessage,
    this.recommendations = const [],
  });

  AIState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<AIRecommendation>? recommendations,
  }) {
    return AIState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      recommendations: recommendations ?? this.recommendations,
    );
  }
}

class AIController extends StateNotifier<AIState> {
  final AIRepository _repository;
  final Ref _ref;

  AIController(this._repository, this._ref) : super(AIState());

  Future<void> loadRecommendations() async {
    final business = await _ref.read(currentBusinessProvider.future);
    if (business == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    
    final result = await _repository.getRecommendations(business.id);
    result.fold(
      (list) => state = state.copyWith(isLoading: false, recommendations: list),
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  Future<void> applyRecommendation(String id) async {
    final result = await _repository.applyRecommendation(id);
    result.fold(
      (_) {
        // Refresh local state
        final updated = state.recommendations.map((r) => r.id == id ? r.copyWith(isApplied: true) : r).toList();
        state = state.copyWith(recommendations: updated);
      },
      (failure) => state = state.copyWith(errorMessage: failure.message),
    );
  }

  Future<void> dismissRecommendation(String id) async {
    final result = await _repository.dismissRecommendation(id);
    result.fold(
      (_) => loadRecommendations(),
      (failure) => state = state.copyWith(errorMessage: failure.message),
    );
  }
}

final aiControllerProvider = StateNotifierProvider<AIController, AIState>((ref) {
  return AIController(ref.watch(aiRepositoryProvider), ref);
});
