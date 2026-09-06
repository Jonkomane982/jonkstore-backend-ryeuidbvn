import '../enums/notification_type.dart';
import '../enums/sync_status.dart';

/// Represents a system or AI-generated notification for a user.
class Notification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final String userId;
  final bool isRead;
  final Map<String, dynamic>? data; // Optional payload for navigation or actions
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.userId,
    this.isRead = false,
    this.data,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'userId': userId,
      'isRead': isRead ? 1 : 0,
      'data': data?.toString(), // SQLite doesn't support JSON directly, stringify for now or use a helper
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      type: NotificationType.values.firstWhere((e) => e.name == json['type']),
      userId: json['userId'],
      isRead: json['isRead'] == 1,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      syncStatus: SyncStatus.values.firstWhere((e) => e.name == json['sync_status']),
    );
  }
}
