import '../../core/network/api_client.dart';
import '../../core/domain/models/ai_recommendation.dart';

/// Remote data source for AI Recommendation operations.
class AIRemoteDataSource {
  final ApiClient _apiClient;

  AIRemoteDataSource(this._apiClient);

  Future<List<AIRecommendation>> getRecommendations(String businessId) async {
    final response = await _apiClient.get('/ai/recommendations', queryParameters: {'businessId': businessId});
    final List data = response.data;
    return data.map((e) => AIRecommendation.fromJson(e)).toList();
  }

  Future<void> applyRecommendation(String id) async {
    await _apiClient.post('/ai/recommendations/$id/apply');
  }

  Future<void> dismissRecommendation(String id) async {
    await _apiClient.post('/ai/recommendations/$id/dismiss');
  }
}
