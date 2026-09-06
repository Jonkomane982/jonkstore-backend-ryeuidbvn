import '../queue/sync_queue.dart';
import '../models/sync_task.dart';
import '../models/sync_state.dart';
import 'sync_logger.dart';
import 'sync_worker_registry.dart';
import '../strategies/conflict_resolver.dart';

/// The core engine responsible for processing the synchronization queue.
/// 
/// It iterates through pending tasks and delegates the actual network 
/// and data operations to specialized [SyncWorker]s.
class SyncEngine {
  final SyncQueue _queue;
  final ConflictResolver _conflictResolver;
  final SyncWorkerRegistry _workerRegistry;

  SyncEngine(this._queue, this._conflictResolver, this._workerRegistry);

  /// Processes all pending tasks in the queue.
  /// 
  /// This method iterates through tasks stored in SQLite and attempts 
  /// to push them to the remote server using the appropriate worker.
  Future<void> processQueue() async {
    final tasks = await _queue.getPendingTasks();
    
    if (tasks.isEmpty) {
      // Periodic Pull logic could be triggered here as well
      await _pullAll();
      return;
    }

    SyncLogger.logQueue(tasks.length);

    for (final task in tasks) {
      await _processTask(task);
    }

    // After pushing local changes, pull latest from server
    await _pullAll();
  }

  Future<void> _processTask(SyncTask task) async {
    SyncLogger.logStart(task.entityName);
    
    final worker = _workerRegistry.getWorker(task.entityName);
    if (worker == null) {
      SyncLogger.logError(task.entityName, task.operation, 'No worker registered for this entity');
      return;
    }

    try {
      await _queue.updateTaskState(task.id, SyncState.uploading);

      final resultState = await worker.push(task);

      if (resultState == SyncState.synced) {
        await _queue.removeTask(task.id);
        SyncLogger.logSuccess(task.entityName, task.operation);
      } else if (resultState == SyncState.conflict) {
        SyncLogger.logConflict(task.entityName, task.entityId);
        await _queue.updateTaskState(task.id, SyncState.conflict);
        // Conflict resolution logic would be triggered here or handled by the worker
      } else {
        await _queue.updateTaskState(task.id, resultState);
      }
      
    } catch (e) {
      SyncLogger.logError(task.entityName, task.operation, e);
      
      if (_shouldRetry(task)) {
        await _queue.updateTaskState(task.id, SyncState.failed, error: e.toString());
      } else {
        // Permanent failure or manual intervention required
        await _queue.updateTaskState(task.id, SyncState.conflict, error: 'Max retries exceeded');
      }
    }
  }

  /// Triggers a pull operation for all registered workers.
  Future<void> _pullAll() async {
    for (final worker in _workerRegistry.allWorkers) {
      try {
        await worker.pull();
      } catch (e) {
        SyncLogger.logError(worker.entityName, 'PULL', e);
      }
    }
  }

  bool _shouldRetry(SyncTask task) {
    return task.retryCount < 3;
  }
}
