import '../models/sync_task.dart';
import '../models/sync_state.dart';

/// Interface for a specialized worker that handles the sync of a specific entity type.
/// 
/// Each repository or service that needs synchronization should implement or 
/// provide a worker that understands how to talk to the Node.js/PostgreSQL backend.
abstract class SyncWorker {
  /// The entity name this worker handles (e.g., 'products', 'sales').
  String get entityName;

  /// Pushes a local change to the remote server.
  /// 
  /// 1. Sends the data to the REST API.
  /// 2. Handles the response (e.g., updating the local ID with the server ID).
  /// 3. Returns the sync result.
  Future<SyncState> push(SyncTask task);

  /// Pulls the latest changes from the remote server for this entity.
  /// 
  /// 1. Fetches data since the 'last_synced_at' timestamp.
  /// 2. Merges or resolves conflicts with local data.
  Future<void> pull();

  /// Merges remote data into the local database, resolving conflicts.
  Future<void> merge(Map<String, dynamic> remoteData);

  /// Reverts a local change if it was rejected by the server and cannot be resolved.
  Future<void> rollback(String entityId);
}
