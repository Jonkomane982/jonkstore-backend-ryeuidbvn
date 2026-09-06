import '../models/sync_task.dart';
import '../models/sync_state.dart';

/// Manages the persistence and retrieval of synchronization tasks.
/// 
/// The queue ensures that local changes are tracked and processed in order.
abstract class SyncQueue {
  /// Adds a new task to the queue.
  Future<void> addTask(SyncTask task);

  /// Retrieves all tasks that are ready for synchronization.
  Future<List<SyncTask>> getPendingTasks();

  /// Updates the state of a specific task.
  Future<void> updateTaskState(String taskId, SyncState state, {String? error});

  /// Removes a task from the queue after successful synchronization.
  Future<void> removeTask(String taskId);

  /// Retrieves tasks that failed and are eligible for retry.
  Future<List<SyncTask>> getFailedTasks();

  /// Clears the entire queue.
  Future<void> clear();
}
