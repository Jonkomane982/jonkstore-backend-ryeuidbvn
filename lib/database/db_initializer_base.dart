import 'package:sqflite/sqflite.dart';

/// Global reference to the initialized database factory.
/// This allows bypassing the restricted global getter on Web.
late final DatabaseFactory appDatabaseFactory;

/// Abstract class to handle platform-specific database initialization.
abstract class DbInitializer {
  /// Initializes the environment and returns the correct [DatabaseFactory].
  Future<DatabaseFactory> init();
}
