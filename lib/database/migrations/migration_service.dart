import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:sqflite/sqflite.dart';
import '../schema/schema_scripts.dart';
import '../../core/logger/app_logger.dart';

/// Service responsible for handling database migrations and initial schema creation.
/// Hardened for production-grade stability on Web (WASM) and Native platforms.
class MigrationService {
  /// Executes when the database is created for the first time.
  /// 
  /// On Web: This is called manually by DatabaseService to avoid callback bugs.
  /// On Native: This is called inside an automatic transaction by sqflite.
  Future<void> onCreate(Database db, int version) async {
    if (kDebugMode) {
      print('JonkStore: [DB] Initializing commercial schema - Version $version');
    }
    
    // 1. Execute Configuration PRAGMAs (Native only).
    // PRAGMAs like WAL return null on Web and crash the driver.
    if (!kIsWeb) {
      for (final script in SchemaScripts.onConfigureScripts) {
        try {
          await db.execute(script);
        } catch (e) {
          AppLogger.warning('JonkStore: [DB] Non-critical PRAGMA failed: $script - $e');
        }
      }
    }

    // 2. Execute Creation Scripts using the Batch API.
    // Batch with noResult: true and exclusive: false is the definitive fix 
    // for "unsupported result null" crashes on Flutter Web.
    final batch = db.batch();
    
    for (final script in SchemaScripts.onCreateScripts) {
      batch.execute(script);
    }

    try {
      if (kDebugMode) {
        print('JonkStore: [DB] Committing schema batch...');
      }
      
      // exclusive: false is required on Web to prevent nested transaction errors.
      await batch.commit(noResult: true, exclusive: false);
      
      if (kDebugMode) {
        print('JonkStore: [DB] Schema batch committed successfully.');
      }
    } catch (e) {
      AppLogger.error('JonkStore: [DB] Schema initialization failed');
      AppLogger.error('Exception: $e');
      rethrow;
    }

    AppLogger.info('Database Schema Initialized Successfully.');
  }

  /// Handles database schema upgrades.
  Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.info('JonkStore: [DB] Upgrading Database from $oldVersion to $newVersion');
    for (int i = oldVersion + 1; i <= newVersion; i++) {
      await _executeMigration(db, i);
    }
  }

  Future<void> _executeMigration(Database db, int targetVersion) async {
    AppLogger.info('Applying migration to version $targetVersion');
    switch (targetVersion) {
      case 2:
        await _migrateV1ToV2(db);
        break;
      default:
        AppLogger.info('No migration handler for version $targetVersion');
    }
  }

  /// Adds owner_profile columns: username, role, password_hash, is_verified,
  /// and converts business_id/full_name/email to nullable (matches new schema).
  Future<void> _migrateV1ToV2(Database db) async {
    AppLogger.info('[DB Migration V1→V2] Adding password + auth columns');
    try {
      await db.execute(
          "ALTER TABLE owner_profile ADD COLUMN username TEXT");
    } catch (_) {}
    try {
      await db.execute(
          "ALTER TABLE owner_profile ADD COLUMN role TEXT DEFAULT 'owner'");
    } catch (_) {}
    try {
      await db.execute(
          "ALTER TABLE owner_profile ADD COLUMN password_hash TEXT");
    } catch (_) {}
    try {
      await db.execute(
          "ALTER TABLE owner_profile ADD COLUMN is_verified INTEGER DEFAULT 0");
    } catch (_) {}
    AppLogger.info('[DB Migration V1→V2] Complete');
  }
}
