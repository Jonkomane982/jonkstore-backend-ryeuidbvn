/// Represents the synchronization state of a local record with the remote server.
enum SyncStatus {
  /// Record created locally, not yet pushed to server.
  pending,

  /// Record is in sync with the server.
  synced,

  /// Existing record updated locally, change not yet pushed to server.
  updated,

  /// Record marked for deletion locally, not yet deleted on server.
  deleted,

  /// Last synchronization attempt failed.
  failed,
}
