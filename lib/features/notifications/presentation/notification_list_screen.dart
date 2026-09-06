import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/features/notifications/controllers/notification_controller.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/loading/empty_state.dart';
import 'package:jonkstore/shared/cards/notification_card.dart';
import 'package:jonkstore/core/domain/enums/notification_type.dart';

class NotificationListScreen extends ConsumerStatefulWidget {
  const NotificationListScreen({super.key});

  @override
  ConsumerState<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends ConsumerState<NotificationListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(notificationControllerProvider.notifier).loadNotifications(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.notifications.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(notificationControllerProvider.notifier).markAllAsRead(),
              child: const Text('Mark all as read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationControllerProvider.notifier).loadNotifications(),
        child: _buildContent(state),
      ),
    );
  }

  Widget _buildContent(NotificationState state) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }

    if (state.errorMessage != null && state.notifications.isEmpty) {
      return Center(child: Text(state.errorMessage!));
    }

    if (state.notifications.isEmpty) {
      return const EmptyState(
        title: 'No Notifications',
        message: 'System alerts and AI insights will appear here.',
        icon: Icons.notifications_none_rounded,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: state.notifications.length,
      itemBuilder: (context, index) {
        final notification = state.notifications[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Opacity(
            opacity: notification.isRead ? 0.6 : 1.0,
            child: NotificationCard(
              title: notification.title,
              message: notification.message,
              icon: _getIcon(notification.type),
              iconColor: _getColor(notification.type),
              time: notification.createdAt,
              onTap: () {
                if (!notification.isRead) {
                  ref.read(notificationControllerProvider.notifier).markAsRead(notification.id);
                }
              },
            ),
          ),
        );
      },
    );
  }

  IconData _getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.warning: return Icons.warning_amber_rounded;
      case NotificationType.success: return Icons.check_circle_outline_rounded;
      case NotificationType.error: return Icons.error_outline_rounded;
      case NotificationType.ai: return Icons.auto_awesome;
      case NotificationType.info: return Icons.info_outline_rounded;
    }
  }

  Color _getColor(NotificationType type) {
    switch (type) {
      case NotificationType.warning: return AppColors.warning;
      case NotificationType.success: return AppColors.success;
      case NotificationType.error: return AppColors.error;
      case NotificationType.ai: return AppColors.primary;
      case NotificationType.info: return AppColors.info;
    }
  }
}
