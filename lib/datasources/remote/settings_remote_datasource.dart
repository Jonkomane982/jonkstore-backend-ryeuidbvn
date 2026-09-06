import '../../core/network/api_client.dart';
import '../../core/domain/models/settings.dart';

/// Remote data source for Settings operations.
class SettingsRemoteDataSource {
  final ApiClient _apiClient;

  SettingsRemoteDataSource(this._apiClient);

  Future<Settings> updateSettings(Settings settings) async {
    final response = await _apiClient.put('/settings/${settings.businessId}', data: settings.toJson());
    return Settings.fromJson(response.data);
  }

  Future<Settings?> getSettings(String businessId) async {
    final response = await _apiClient.get('/settings/$businessId');
    return response.data != null ? Settings.fromJson(response.data) : null;
  }
}
