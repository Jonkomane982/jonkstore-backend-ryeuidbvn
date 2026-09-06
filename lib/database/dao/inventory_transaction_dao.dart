import 'package:sqflite/sqflite.dart';
import '../database_service.dart';
import '../database_constants.dart';
import '../../core/domain/models/inventory_transaction.dart';

/// Data Access Object for immutable inventory transactions.
class InventoryTransactionDao {
  final DatabaseService _databaseService;

  InventoryTransactionDao(this._databaseService);

  Future<void> insert(InventoryTransaction transaction, {Transaction? txn}) async {
    final executor = txn ?? await _databaseService.database;
    await executor.insert(
      DatabaseConstants.tableInventoryTransactions,
      transaction.toJson(),
    );
  }

  Future<List<InventoryTransaction>> findByInventoryId(String inventoryId) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableInventoryTransactions,
      where: '${DatabaseConstants.columnInventoryId} = ?',
      whereArgs: [inventoryId],
      orderBy: '${DatabaseConstants.columnCreatedAt} DESC',
    );
    return results.map((e) => InventoryTransaction.fromJson(e)).toList();
  }

  Future<List<InventoryTransaction>> findByProductId(String productId) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableInventoryTransactions,
      where: '${DatabaseConstants.columnProductId} = ?',
      whereArgs: [productId],
      orderBy: '${DatabaseConstants.columnTransactionDate} DESC, '
          '${DatabaseConstants.columnCreatedAt} DESC',
    );
    return results.map((e) => InventoryTransaction.fromJson(e)).toList();
  }

  Future<List<InventoryTransaction>> findRecent({int limit = 50}) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableInventoryTransactions,
      orderBy: '${DatabaseConstants.columnCreatedAt} DESC',
      limit: limit,
    );
    return results.map((e) => InventoryTransaction.fromJson(e)).toList();
  }
}
