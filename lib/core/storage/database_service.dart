import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../logger/app_logger.dart';
import 'database_config.dart';
import 'migration_service.dart';

/// Service responsible for managing the SQLite database connection and operations.
class DatabaseService {
  final MigrationService _migrationService;
  Database? _database;

  DatabaseService(this._migrationService);

  /// Returns the database instance, initializing it if necessary.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DatabaseConfig.databaseName);

    return await openDatabase(
      path,
      version: DatabaseConfig.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _migrationService.onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    AppLogger.info('Creating database version $version');
    // Tables will be created here or via a dedicated Schema class
  }

  /// Closes the database connection.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
