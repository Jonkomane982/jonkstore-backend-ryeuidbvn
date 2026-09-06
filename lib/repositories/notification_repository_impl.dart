import 'dart:async';
import 'package:jonkstore/core/domain/models/notification.dart';
import 'package:jonkstore/core/network/result.dart';
import 'package:jonkstore/core/errors/failures.dart';
import 'package:jonkstore/datasources/local/notification_local_datasource.dart';
import 'package:jonkstore/datasources/remote/notification_remote_datasource.dart';
import 'package:jonkstore/sync/mixins/syncable_repository_mixin.dart';
import 'package:jonkstore/sync/queue/sync_queue.dart';
import 'notification_repository.dart';

/// Production implementation of [NotificationRepository] using SQLite.
class NotificationRepositoryImpl with SyncableRepositoryMixin implements NotificationRepository {
  final NotificationLocalDataSource localDataSource;
  final NotificationRemoteDataSource remoteDataSource;
  
  @override
  final SyncQueue syncQueue;

  @override
  String get entityName => 'notifications';

  final _streamController = StreamController<List<Notification>>.broadcast();

  NotificationRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.syncQueue,
  });

  @override
  Future<Result<void>> markAsRead(String id) async {
    try {
      await localDataSource.markAsRead(id);
      
      // Enqueue sync task
      await enqueueSyncTask(
        entityId: id,
        operation: 'UPDATE',
        data: {'isRead': 1},
      );

      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> markAllAsRead(String userId) async {
    try {
      await localDataSource.markAllAsRead(userId);
      
      // Enqueue sync task for bulk update
      await enqueueSyncTask(
        entityId: userId,
        operation: 'UPDATE_ALL_READ',
        data: {'userId': userId},
      );

      _refresh(userId);
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Notification>>> findAll(String userId) async {
    try {
      final notifications = await localDataSource.findAll(userId);
      return Result.success(notifications);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<int>> countUnread(String userId) async {
    try {
      final count = await localDataSource.countUnread(userId);
      return Result.success(count);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Stream<List<Notification>> watchUnread(String userId) {
    _refresh(userId);
    return _streamController.stream.map((list) => list.where((n) => !n.isRead).toList());
  }

  @override
  Future<Result<void>> sync() async {
    return Result.success(null);
  }

  void _refresh(String userId) async {
    try {
      final notifications = await localDataSource.findAll(userId);
      _streamController.add(notifications);
    } catch (_) {}
  }
}
