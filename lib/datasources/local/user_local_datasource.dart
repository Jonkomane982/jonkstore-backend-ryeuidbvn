import '../../database/database_service.dart';
import '../../core/domain/models/user.dart';
import '../../database/database_constants.dart';

/// Local data source for User operations using SQLite.
/// Now correctly maps to the 'employees' table in the professional schema.
class UserLocalDataSource {
  final DatabaseService _databaseService;

  UserLocalDataSource(this._databaseService);

  Future<void> insert(User user) async {
    final db = await _databaseService.database;
    await db.insert(DatabaseConstants.tableEmployees, user.toJson());
  }

  Future<void> update(User user) async {
    final db = await _databaseService.database;
    await db.update(
      DatabaseConstants.tableEmployees,
      user.toJson(),
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [user.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _databaseService.database;
    await db.delete(
      DatabaseConstants.tableEmployees,
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  Future<User?> findById(String id) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableEmployees,
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? User.fromJson(results.first) : null;
  }

  Future<List<User>> findAll() async {
    final db = await _databaseService.database;
    final results = await db.query(DatabaseConstants.tableEmployees);
    return results.map((e) => User.fromJson(e)).toList();
  }
}
