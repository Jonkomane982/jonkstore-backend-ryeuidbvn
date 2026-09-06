import '../workers/sync_worker.dart';

/// A registry that holds all entity-specific synchronization workers.
/// 
/// The [SyncEngine] uses this registry to find the correct worker 
/// for a given entity name when processing tasks from the queue.
class SyncWorkerRegistry {
  final Map<String, SyncWorker> _workers = {};

  /// Registers a worker for a specific entity.
  void register(SyncWorker worker) {
    _workers[worker.entityName] = worker;
  }

  /// Retrieves a worker for the given entity name.
  SyncWorker? getWorker(String entityName) {
    return _workers[entityName];
  }

  /// Returns all registered workers.
  Iterable<SyncWorker> get allWorkers => _workers.values;
}
