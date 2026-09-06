/// Represents the synchronization state of a local record with the remote server.
/// 
/// This is used to track changes for eventual synchronization with a PostgreSQL backend.
enum SyncStatus {
  /// Record created locally, not yet pushed to server.
  created,

  /// Existing record updated locally, change not yet pushed to server.
  updated,

  /// Record marked for deletion locally, not yet deleted on server.
  deleted,

  /// Record is in sync with the server.
  synced,

  /// Synchronization is currently in progress.
  pending,

  /// Last synchronization attempt failed.
  failed,
}

/// Extension to handle string conversion for SQLite storage.
extension SyncStatusX on SyncStatus {
  String get value => name;

  static SyncStatus fromValue(String value) {
    return SyncStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SyncStatus.created,
    );
  }
}
