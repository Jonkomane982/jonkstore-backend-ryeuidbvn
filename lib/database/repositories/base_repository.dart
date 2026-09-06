import 'package:sqflite/sqflite.dart';
import '../database_service.dart';
import '../database_constants.dart';

/// A generic repository providing basic CRUD operations for SQLite tables.
/// 
/// [T] represents the model type.
/// [M] represents the Map type returned by SQLite (usually Map<String, dynamic>).
abstract class BaseRepository<T> {
  final DatabaseService databaseService;
  final String tableName;

  BaseRepository(this.databaseService, this.tableName);

  /// Converts a Map from the database into an object of type [T].
  T fromMap(Map<String, dynamic> map);

  /// Converts an object of type [T] into a Map for database storage.
  Map<String, dynamic> toMap(T item);

  /// Inserts a new record into the database.
  Future<int> insert(T item) async {
    final db = await databaseService.database;
    return await db.insert(
      tableName,
      toMap(item),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates an existing record in the database.
  Future<int> update(T item, String id) async {
    final db = await databaseService.database;
    return await db.update(
      tableName,
      toMap(item),
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  /// Deletes a record from the database by its ID.
  Future<int> delete(String id) async {
    final db = await databaseService.database;
    return await db.delete(
      tableName,
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  /// Finds a single record by its ID.
  Future<T?> findById(String id) async {
    final db = await databaseService.database;
    final results = await db.query(
      tableName,
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );

    if (results.isNotEmpty) {
      return fromMap(results.first);
    }
    return null;
  }

  /// Returns all records from the table.
  Future<List<T>> findAll() async {
    final db = await databaseService.database;
    final results = await db.query(tableName);
    return results.map((map) => fromMap(map)).toList();
  }

  /// Checks if a record with the given ID exists.
  Future<bool> exists(String id) async {
    final db = await databaseService.database;
    final results = await db.rawQuery(
      'SELECT 1 FROM $tableName WHERE ${DatabaseConstants.columnId} = ? LIMIT 1',
      [id],
    );
    return results.isNotEmpty;
  }

  /// Returns the total count of records in the table.
  Future<int> count() async {
    final db = await databaseService.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM $tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
