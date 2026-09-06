/// Configuration for the JonkStore SQLite database.
class DatabaseConfig {
  DatabaseConfig._();

  static const String databaseName = 'jonkstore_pos.db';
  static const int databaseVersion = 2;

  /// Whether to enable foreign keys in SQLite.
  static const bool enableForeignKeys = true;
}
