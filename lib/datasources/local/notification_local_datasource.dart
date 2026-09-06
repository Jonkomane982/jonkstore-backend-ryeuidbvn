import 'package:sqflite/sqflite.dart';
import '../../database/database_service.dart';
import '../../core/domain/models/notification.dart';
import '../../database/database_constants.dart';

/// Local data source for Notification operations using SQLite.
class NotificationLocalDataSource {
  final DatabaseService _databaseService;

  NotificationLocalDataSource(this._databaseService);

  Future<void> insert(Notification notification) async {
    final db = await _databaseService.database;
    await db.insert(DatabaseConstants.tableNotifications, notification.toJson());
  }

  Future<void> update(Notification notification) async {
    final db = await _databaseService.database;
    await db.update(
      DatabaseConstants.tableNotifications,
      notification.toJson(),
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [notification.id],
    );
  }

  Future<void> markAsRead(String id) async {
    final db = await _databaseService.database;
    await db.update(
      DatabaseConstants.tableNotifications,
      {'isRead': 1},
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllAsRead(String userId) async {
    final db = await _databaseService.database;
    await db.update(
      DatabaseConstants.tableNotifications,
      {'isRead': 1},
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

  Future<List<Notification>> findAll(String userId) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableNotifications,
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: '${DatabaseConstants.columnCreatedAt} DESC',
    );
    return results.map((e) => Notification.fromJson(e)).toList();
  }

  Future<int> countUnread(String userId) async {
    final db = await _databaseService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseConstants.tableNotifications} WHERE userId = ? AND isRead = 0',
      [userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
