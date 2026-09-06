import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';
import 'database_config.dart';
import 'db_initializer.dart';
import 'migrations/migration_service.dart';
import '../core/logger/app_logger.dart';

/// Centralized service for SQLite database operations.
/// 
/// Hardened for production use by isolating platform-specific initialization 
/// quirks, especially for Flutter Web (WASM).
class DatabaseService {
  final MigrationService _migrationService;
  Database? _db;
  final _lock = Lock();

  DatabaseService(this._migrationService);

  /// Returns the current database instance. Opens it if not already open.
  Future<Database> get database async {
    if (_db != null) return _db!;

    return await _lock.synchronized(() async {
      if (_db != null) return _db!;
      _db = await _initDb();
      return _db!;
    });
  }

  Future<Database> _initDb() async {
    String path;
    
    try {
      if (kIsWeb) {
        path = DatabaseConfig.databaseName;
        if (kDebugMode) print('JonkStore: [Web] Opening database factory connection...');
      } else {
        final dbPath = await appDatabaseFactory.getDatabasesPath();
        path = join(dbPath, DatabaseConfig.databaseName);
        if (kDebugMode) print('JonkStore: [Native] Opening database at: $path');
      }

      if (kIsWeb) {
        // ON WEB: Open WITHOUT 'version' or 'onCreate' to bypass internal driver 
        // bugs that return null and crash. We handle versioning and creation manually.
        final db = await appDatabaseFactory.openDatabase(path);
        
        // 1. Manually check the current version using user_version pragma.
        final versionResult = await db.rawQuery('PRAGMA user_version');
        final currentVersion = Sqflite.firstIntValue(versionResult) ?? 0;
        
        if (currentVersion == 0) {
          if (kDebugMode) print('JonkStore: [Web] Initializing fresh commercial schema...');
          // On Web, onCreate is called manually and its internal scripts are hardened.
          await _migrationService.onCreate(db, DatabaseConfig.databaseVersion);
          // Set version manually to signal initialization is complete.
          await db.execute('PRAGMA user_version = ${DatabaseConfig.databaseVersion}');
        } else if (currentVersion < DatabaseConfig.databaseVersion) {
          if (kDebugMode) print('JonkStore: [Web] Upgrading schema from $currentVersion...');
          await _migrationService.onUpgrade(db, currentVersion, DatabaseConfig.databaseVersion);
          await db.execute('PRAGMA user_version = ${DatabaseConfig.databaseVersion}');
        }
        
        if (kDebugMode) print('JonkStore: [Web] Database ready.');
        return db;
      } else {
        // ON NATIVE: Use the standard robust callback system.
        return await appDatabaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: DatabaseConfig.databaseVersion,
            onCreate: _migrationService.onCreate,
            onUpgrade: _migrationService.onUpgrade,
            onConfigure: (db) async {
              if (DatabaseConfig.enableForeignKeys) {
                await db.execute('PRAGMA foreign_keys = ON');
              }
            },
          ),
        );
      }
    } catch (e, stack) {
      AppLogger.error('Critical: Failed to initialize database: $e');
      if (kDebugMode) {
        print('DB Init Error: $e');
        print(stack);
      }
      rethrow;
    }
  }

  /// Closes the database connection.
  Future<void> close() async {
    await _lock.synchronized(() async {
      if (_db != null) {
        await _db!.close();
        _db = null;
        AppLogger.info('SQLite database connection closed');
      }
    });
  }

  // Helper execution methods used by Repositories and Data Sources

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  Future<void> execute(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    await db.execute(sql, arguments);
  }

  Future<List<dynamic>> batch(void Function(Batch batch) action) async {
    final db = await database;
    final batch = db.batch();
    action(batch);
    return await batch.commit();
  }
}
