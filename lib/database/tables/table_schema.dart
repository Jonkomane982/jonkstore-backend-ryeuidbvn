import '../database_constants.dart';

/// Base schema for placeholder tables.
abstract class TableSchema {
  static String createTableQuery(String tableName) {
    return '''
      CREATE TABLE $tableName (
        ${DatabaseConstants.columnId} TEXT PRIMARY KEY,
        ${DatabaseConstants.columnCreatedAt} TEXT NOT NULL,
        ${DatabaseConstants.columnUpdatedAt} TEXT NOT NULL,
        ${DatabaseConstants.columnSyncStatus} TEXT NOT NULL,
        ${DatabaseConstants.columnServerId} TEXT,
        ${DatabaseConstants.columnLastSyncedAt} TEXT
      )
    ''';
  }
}
