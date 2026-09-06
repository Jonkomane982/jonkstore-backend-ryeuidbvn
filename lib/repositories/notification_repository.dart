import '../core/domain/models/notification.dart';
import '../core/network/result.dart';

/// Interface for Notification repository operations.
abstract class NotificationRepository {
  Future<Result<void>> markAsRead(String id);
  Future<Result<void>> markAllAsRead(String userId);
  Future<Result<List<Notification>>> findAll(String userId);
  Future<Result<int>> countUnread(String userId);
  
  Stream<List<Notification>> watchUnread(String userId);
  Future<Result<void>> sync();
}
