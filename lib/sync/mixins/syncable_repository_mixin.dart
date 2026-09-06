import 'package:uuid/uuid.dart';
import '../models/sync_task.dart';
import '../models/sync_state.dart';
import '../queue/sync_queue.dart';

/// A mixin that provides synchronization capabilities to repositories.
/// 
/// Repositories using this mixin can easily enqueue local changes into 
/// the synchronization queue to be processed by the [SyncEngine].
mixin SyncableRepositoryMixin {
  SyncQueue get syncQueue;
  String get entityName;

  /// Enqueues a synchronization task for a local change.
  /// 
  /// [entityId] - The unique identifier of the entity being changed.
  /// [operation] - The type of operation ('CREATE', 'UPDATE', 'DELETE').
  /// [data] - The serialized data of the entity.
  Future<void> enqueueSyncTask({
    required String entityId,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    final task = SyncTask(
      id: const Uuid().v4(),
      entityName: entityName,
      entityId: entityId,
      operation: operation,
      data: data,
      state: SyncState.pending,
      createdAt: DateTime.now(),
    );

    await syncQueue.addTask(task);
  }
}
