import 'package:sqflite/sqflite.dart';
import '../database_service.dart';
import '../database_constants.dart';
import '../../core/domain/models/inventory.dart';

/// Data Access Object for authoritative stock management.
/// 
/// Handles low-level SQLite queries for current stock levels, joining with 
/// products for real-time reporting and barcode lookups.
class InventoryDao {
  final DatabaseService _databaseService;

  InventoryDao(this._databaseService);

  /// Upserts an inventory record (Initial creation or metadata updates).
  Future<void> upsert(Inventory inventory, {Transaction? txn}) async {
    final executor = txn ?? await _databaseService.database;
    await executor.insert(
      DatabaseConstants.tableInventory,
      inventory.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Atomically updates stock level for a specific inventory ID.
  Future<void> updateStockLevel(String id, double newQuantity, {required Transaction txn}) async {
    await txn.update(
      DatabaseConstants.tableInventory,
      {
        DatabaseConstants.columnQuantity: newQuantity,
        DatabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.columnSyncStatus: 'UPDATED',
      },
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  /// Finds an inventory record by product and branch.
  Future<Inventory?> findByProductId(String productId, String branchId) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableInventory,
      where: '${DatabaseConstants.columnProductId} = ? AND ${DatabaseConstants.columnBranchId} = ? AND ${DatabaseConstants.columnIsDeleted} = 0',
      whereArgs: [productId, branchId],
      limit: 1,
    );
    return results.isNotEmpty ? Inventory.fromJson(results.first) : null;
  }

  /// Finds inventory record using barcode search on joined product table.
  /// Used for offline-first barcode scanning.
  Future<Inventory?> findByBarcode(String barcode, String branchId) async {
    final db = await _databaseService.database;
    final results = await db.rawQuery('''
      SELECT i.* FROM ${DatabaseConstants.tableInventory} i
      JOIN ${DatabaseConstants.tableProducts} p ON i.${DatabaseConstants.columnProductId} = p.id
      WHERE p.${DatabaseConstants.columnBarcode} = ? 
        AND i.${DatabaseConstants.columnBranchId} = ?
        AND i.${DatabaseConstants.columnIsDeleted} = 0
        AND p.${DatabaseConstants.columnIsDeleted} = 0
        AND p.${DatabaseConstants.columnIsActive} = 1
      LIMIT 1
    ''', [barcode, branchId]);
    
    return results.isNotEmpty ? Inventory.fromJson(results.first) : null;
  }

  /// Retrieves inventory with joined product info for production list views.
  Future<List<Map<String, dynamic>>> getInventoryWithProductInfo({
    String? branchId,
    bool lowStockOnly = false,
    bool outOfStockOnly = false,
    String? searchQuery,
    String? categoryId,
    String? supplierId,
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
    
    if (outOfStockOnly) {
      query += ' AND i.${DatabaseConstants.columnQuantity} <= 0';
    } else if (lowStockOnly) {
      query += ' AND i.${DatabaseConstants.columnQuantity} <= i.${DatabaseConstants.columnLowStockThreshold}';
    }
    
    if (categoryId != null) {
      query += ' AND p.${DatabaseConstants.columnCategoryId} = ?';
      args.add(categoryId);
    }

    if (supplierId != null) {
      query += ' AND p.${DatabaseConstants.columnSupplierId} = ?';
      args.add(supplierId);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim()}%';
      query += ' AND (p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ?)';
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

  /// Calculates total inventory value for a branch based on cost price.
  Future<double> getInventoryValuation(String branchId) async {
    final db = await _databaseService.database;
    final result = await db.rawQuery('''
      SELECT SUM(i.${DatabaseConstants.columnQuantity} * p.${DatabaseConstants.columnCostPrice}) as total_value
      FROM ${DatabaseConstants.tableInventory} i
      JOIN ${DatabaseConstants.tableProducts} p ON i.${DatabaseConstants.columnProductId} = p.id
      WHERE i.${DatabaseConstants.columnBranchId} = ? AND i.${DatabaseConstants.columnIsDeleted} = 0
    ''', [branchId]);
    
    return (result.first['total_value'] as num?)?.toDouble() ?? 0.0;
  }
}
