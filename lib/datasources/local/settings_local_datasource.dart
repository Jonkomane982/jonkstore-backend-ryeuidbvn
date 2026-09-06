import '../../database/database_service.dart';
import '../../core/domain/models/settings.dart';
import '../../database/database_constants.dart';

/// Local data source for Settings operations using SQLite.
/// Now correctly maps to the 'app_settings' table in the professional schema.
class SettingsLocalDataSource {
  final DatabaseService _databaseService;

  SettingsLocalDataSource(this._databaseService);

  Future<void> insert(Settings settings) async {
    final db = await _databaseService.database;
    await db.insert(DatabaseConstants.tableAppSettings, settings.toJson());
  }

  Future<void> update(Settings settings) async {
    final db = await _databaseService.database;
    await db.update(
      DatabaseConstants.tableAppSettings,
      settings.toJson(),
      where: 'businessId = ?',
      whereArgs: [settings.businessId],
    );
  }

  Future<Settings?> getSettings(String businessId) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableAppSettings,
      where: 'businessId = ?',
      whereArgs: [businessId],
    );
    return results.isNotEmpty ? Settings.fromJson(results.first) : null;
  }
}
