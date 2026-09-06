import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/core/domain/models/notification.dart' as model;
import 'package:jonkstore/repositories/notification_repository.dart';
import 'package:jonkstore/providers/repository_providers.dart';
import 'package:jonkstore/providers/auth_providers.dart';

class NotificationState {
  final bool isLoading;
  final String? errorMessage;
  final List<model.Notification> notifications;

  NotificationState({
    this.isLoading = false,
    this.errorMessage,
    this.notifications = const [],
  });

  NotificationState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<model.Notification>? notifications,
  }) {
    return NotificationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      notifications: notifications ?? this.notifications,
    );
  }
}

class NotificationController extends StateNotifier<NotificationState> {
  final NotificationRepository _repository;
  final Ref _ref;

  NotificationController(this._repository, this._ref) : super(NotificationState());

  Future<void> loadNotifications() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    
    final result = await _repository.findAll(user.id);
    result.fold(
      (notifications) => state = state.copyWith(isLoading: false, notifications: notifications),
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  Future<void> markAsRead(String id) async {
    final result = await _repository.markAsRead(id);
    result.fold(
      (_) {
        final updatedList = state.notifications.map((n) {
          return n.id == id ? model.Notification(
            id: n.id,
            title: n.title,
            message: n.message,
            type: n.type,
            userId: n.userId,
            isRead: true,
            data: n.data,
            createdAt: n.createdAt,
            updatedAt: DateTime.now(),
            syncStatus: n.syncStatus,
          ) : n;
        }).toList();
        state = state.copyWith(notifications: updatedList);
      },
      (failure) => state = state.copyWith(errorMessage: failure.message),
    );
  }

  Future<void> markAllAsRead() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    final result = await _repository.markAllAsRead(user.id);
    result.fold(
      (_) => loadNotifications(),
      (failure) => state = state.copyWith(errorMessage: failure.message),
    );
  }
}

final notificationControllerProvider = StateNotifierProvider<NotificationController, NotificationState>((ref) {
  return NotificationController(ref.watch(notificationRepositoryProvider), ref);
});
