/// Represents the current state of a synchronization task in the queue.
enum SyncState {
  /// Task is waiting to be processed.
  pending,

  /// Task is currently being sent to the remote server.
  uploading,

  /// Data is being fetched from the remote server.
  downloading,

  /// Task completed successfully and data is in sync.
  synced,

  /// A conflict was detected between local and remote data.
  conflict,

  /// Task failed due to network or server error.
  failed,

  /// Record is marked for deletion and needs to be synced.
  deleted,
}
