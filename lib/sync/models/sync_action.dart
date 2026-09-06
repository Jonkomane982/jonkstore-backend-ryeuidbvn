/// Defines the type of data modification operation for synchronization.
/// Aligned with the commercial SQLite and PostgreSQL schemas.
enum SyncAction {
  /// Maps to INSERT in the sync_queue table.
  insert,

  /// Maps to UPDATE in the sync_queue table.
  update,

  /// Maps to DELETE in the sync_queue table.
  delete,
}

extension SyncActionX on SyncAction {
  /// Returns the uppercase string representation used in the SQLite operation column.
  String get value => name.toUpperCase();
}
