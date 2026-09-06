import '../../core/network/api_client.dart';
import '../../core/domain/models/business.dart';

/// Remote data source for Business operations.
class BusinessRemoteDataSource {
  final ApiClient _apiClient;

  BusinessRemoteDataSource(this._apiClient);

  Future<Business> createBusiness(Business business) async {
    final response = await _apiClient.post('/businesses', data: business.toJson());
    return Business.fromJson(response.data);
  }

  Future<Business> updateBusiness(Business business) async {
    final response = await _apiClient.put('/businesses/${business.id}', data: business.toJson());
    return Business.fromJson(response.data);
  }

  Future<Business?> getBusiness(String id) async {
    final response = await _apiClient.get('/businesses/$id');
    return response.data != null ? Business.fromJson(response.data) : null;
  }
}
