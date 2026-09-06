import 'package:sqflite/sqflite.dart';
import '../../database/database_service.dart';
import '../../core/domain/models/business.dart';
import '../../database/database_constants.dart';

/// Local data source for Business operations using SQLite.
class BusinessLocalDataSource {
  final DatabaseService _databaseService;

  BusinessLocalDataSource(this._databaseService);

  Future<void> insert(Business business, {Transaction? txn}) async {
    final executor = txn ?? await _databaseService.database;
    await executor.insert(DatabaseConstants.tableBusinesses, business.toJson());
  }

  Future<void> update(Business business, {Transaction? txn}) async {
    final executor = txn ?? await _databaseService.database;
    await executor.update(
      DatabaseConstants.tableBusinesses,
      business.toJson(),
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [business.id],
    );
  }

  Future<Business?> findById(String id) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableBusinesses,
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? Business.fromJson(results.first) : null;
  }

  Future<List<Business>> findAll() async {
    final db = await _databaseService.database;
    final results = await db.query(DatabaseConstants.tableBusinesses);
    return results.map((e) => Business.fromJson(e)).toList();
  }
}
