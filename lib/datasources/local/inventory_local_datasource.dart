import 'package:sqflite/sqflite.dart';
import '../../database/database_service.dart';
import '../../core/domain/models/inventory.dart';
import '../../core/domain/models/inventory_transaction.dart';
import '../../core/domain/models/inventory_adjustment.dart';
import '../../core/domain/models/inventory_count.dart';
import '../../database/database_constants.dart';

/// Local data source for Inventory and Stock operations using SQLite.
/// Handles current stock, audit logs, adjustments and stock counts.
class InventoryLocalDataSource {
  final DatabaseService _databaseService;

  InventoryLocalDataSource(this._databaseService);

  /// Inserts or updates current stock record.
  Future<void> upsertInventory(Inventory inventory, {Transaction? txn}) async {
    final db = txn ?? await _databaseService.database;
    await db.insert(
      DatabaseConstants.tableInventory,
      inventory.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates inventory levels inside an existing transaction.
  Future<void> updateQuantity(String inventoryId, double newQuantity, {required Transaction txn}) async {
    await txn.update(
      DatabaseConstants.tableInventory,
      {
        DatabaseConstants.columnQuantity: newQuantity,
        DatabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [inventoryId],
    );
  }

  /// Finds inventory record for a product at a branch.
  Future<Inventory?> findByProductId(String productId, String branchId) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableInventory,
      where: '${DatabaseConstants.columnProductId} = ? AND ${DatabaseConstants.columnBranchId} = ?',
      whereArgs: [productId, branchId],
      limit: 1,
    );
    return results.isNotEmpty ? Inventory.fromJson(results.first) : null;
  }

  /// Retrieves full inventory with joined product details for the list view.
  Future<List<Map<String, dynamic>>> findAllWithProductInfo({
    String? branchId,
    bool lowStockOnly = false,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    final db = await _databaseService.database;
    
    String query = '''
      SELECT i.*, p.name, p.sku, p.barcode, p.image_url, p.price, p.cost_price 
      FROM ${DatabaseConstants.tableInventory} i
      JOIN ${DatabaseConstants.tableProducts} p ON i.${DatabaseConstants.columnProductId} = p.id
      WHERE i.${DatabaseConstants.columnIsDeleted} = 0
    ''';
    
    List<dynamic> args = [];
    if (branchId != null) {
      query += ' AND i.${DatabaseConstants.columnBranchId} = ?';
      args.add(branchId);
    }
    
    if (lowStockOnly) {
      query += ' AND i.${DatabaseConstants.columnQuantity} <= i.${DatabaseConstants.columnLowStockThreshold}';
    }
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query += ' AND (p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ?)';
      final q = '%$searchQuery%';
      args.addAll([q, q, q]);
    }
    
    query += ' ORDER BY p.name ASC';
    
    if (limit != null) {
      query += ' LIMIT ?';
      args.add(limit);
      if (offset != null) {
        query += ' OFFSET ?';
        args.add(offset);
      }
    }
    
    return await db.rawQuery(query, args);
  }

  /// Inserts an immutable transaction record.
  Future<void> insertTransaction(InventoryTransaction transaction, {Transaction? txn}) async {
    final db = txn ?? await _databaseService.database;
    await db.insert(DatabaseConstants.tableInventoryTransactions, transaction.toJson());
  }

  /// Retrieves history for an inventory item.
  Future<List<InventoryTransaction>> getTransactionsByInventoryId(String inventoryId) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableInventoryTransactions,
      where: '${DatabaseConstants.columnInventoryId} = ?',
      whereArgs: [inventoryId],
      orderBy: '${DatabaseConstants.columnTransactionDate} DESC',
    );
    return results.map((e) => InventoryTransaction.fromJson(e)).toList();
  }

  /// Retrieves history for a product across all branches.
  Future<List<InventoryTransaction>> getTransactionsByProductId(String productId) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableInventoryTransactions,
      where: '${DatabaseConstants.columnProductId} = ?',
      whereArgs: [productId],
      orderBy: '${DatabaseConstants.columnTransactionDate} DESC',
    );
    return results.map((e) => InventoryTransaction.fromJson(e)).toList();
  }

  /// Atomic execution of stock adjustments.
  Future<void> insertAdjustment(InventoryAdjustment adjustment, {Transaction? txn}) async {
    final db = txn ?? await _databaseService.database;
    await db.insert(DatabaseConstants.tableInventoryAdjustments, adjustment.toJson());
  }

  /// Atomic execution of stock counts.
  Future<void> insertCount(InventoryCount count, {Transaction? txn}) async {
    final db = txn ?? await _databaseService.database;
    await db.insert(DatabaseConstants.tableInventoryCounts, count.toJson());
  }
}
