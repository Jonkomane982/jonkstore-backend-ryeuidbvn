import '../core/domain/models/ai_recommendation.dart';
import '../core/network/result.dart';

/// Interface for AI repository operations.
abstract class AIRepository {
  Future<Result<List<AIRecommendation>>> getRecommendations(String businessId);
  Future<Result<void>> applyRecommendation(String id);
  Future<Result<void>> dismissRecommendation(String id);
  
  Stream<List<AIRecommendation>> watchRecommendations(String businessId);
  Future<Result<void>> sync();
}
