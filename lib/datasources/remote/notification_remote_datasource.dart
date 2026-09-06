import '../../core/network/api_client.dart';
import '../../core/domain/models/notification.dart';

/// Remote data source for Notification operations.
class NotificationRemoteDataSource {
  final ApiClient _apiClient;

  NotificationRemoteDataSource(this._apiClient);

  Future<void> markAsRead(String id) async {
    await _apiClient.put('/notifications/$id/read');
  }

  Future<void> markAllAsRead(String userId) async {
    await _apiClient.put('/notifications/read-all', data: {'userId': userId});
  }

  Future<List<Notification>> getAllNotifications(String userId) async {
    final response = await _apiClient.get('/notifications', queryParameters: {'userId': userId});
    final List data = response.data;
    return data.map((e) => Notification.fromJson(e)).toList();
  }
}
