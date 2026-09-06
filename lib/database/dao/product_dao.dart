import 'package:sqflite/sqflite.dart';
import '../database_service.dart';
import '../database_constants.dart';
import '../../core/domain/models/product.dart';

/// Data Access Object for Product operations.
/// 
/// Implements high-performance SQLite queries with support for 3NF joins
/// (Categories, Suppliers, Inventory) and efficient searching/filtering.
class ProductDao {
  final DatabaseService _databaseService;

  ProductDao(this._databaseService);

  /// Inserts a product and its category relationship in a single transaction.
  Future<void> insert(Product product) async {
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      await txn.insert(
        DatabaseConstants.tableProducts,
        product.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (product.categoryId != null) {
        await txn.insert(
          DatabaseConstants.tableProductCategories,
          {
            'id': '${product.id}_${product.categoryId}',
            'product_id': product.id,
            'category_id': product.categoryId,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'sync_status': 'PENDING',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Updates product details and refreshes category linkage.
  Future<int> update(Product product) async {
    final db = await _databaseService.database;
    return await db.transaction((txn) async {
      final rows = await txn.update(
        DatabaseConstants.tableProducts,
        product.toJson(),
        where: '${DatabaseConstants.columnId} = ?',
        whereArgs: [product.id],
      );

      if (product.categoryId != null) {
        await txn.delete(
          DatabaseConstants.tableProductCategories,
          where: 'product_id = ?',
          whereArgs: [product.id],
        );
        await txn.insert(
          DatabaseConstants.tableProductCategories,
          {
            'id': '${product.id}_${product.categoryId}',
            'product_id': product.id,
            'category_id': product.categoryId,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'sync_status': 'PENDING',
          },
        );
      }
      return rows;
    });
  }

  /// Toggles activation status.
  Future<int> setActive(String id, bool isActive, String userId) async {
    final db = await _databaseService.database;
    return await db.update(
      DatabaseConstants.tableProducts,
      {
        DatabaseConstants.columnIsActive: isActive ? 1 : 0,
        DatabaseConstants.columnUpdatedBy: userId,
        DatabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.columnSyncStatus: 'UPDATED',
      },
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  /// Soft deletes a product.
  Future<int> softDelete(String id, String userId) async {
    final db = await _databaseService.database;
    return await db.update(
      DatabaseConstants.tableProducts,
      {
        DatabaseConstants.columnIsDeleted: 1,
        DatabaseConstants.columnDeletedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.columnUpdatedBy: userId,
        DatabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.columnSyncStatus: 'DELETED',
      },
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  /// Restores a soft-deleted product.
  Future<int> restore(String id, String userId) async {
    final db = await _databaseService.database;
    return await db.update(
      DatabaseConstants.tableProducts,
      {
        DatabaseConstants.columnIsDeleted: 0,
        DatabaseConstants.columnDeletedAt: null,
        DatabaseConstants.columnUpdatedBy: userId,
        DatabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.columnSyncStatus: 'UPDATED',
      },
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  /// Finds a specific product with its category ID and current stock joined.
  Future<Product?> findById(String id) async {
    final db = await _databaseService.database;
    final results = await db.rawQuery('''
      SELECT p.*, pc.category_id, COALESCE(SUM(i.quantity), 0) as current_stock
      FROM ${DatabaseConstants.tableProducts} p
      LEFT JOIN ${DatabaseConstants.tableProductCategories} pc ON p.id = pc.product_id
      LEFT JOIN ${DatabaseConstants.tableInventory} i ON p.id = i.product_id
      WHERE p.id = ? 
      GROUP BY p.id LIMIT 1
    ''', [id]);

    if (results.isNotEmpty) {
      return Product.fromJson(results.first);
    }
    return null;
  }

  /// Retrieves products with complex filtering, searching, and inventory joins.
  Future<List<Product>> findAll({
    String? searchQuery,
    String? categoryId,
    String? supplierId,
    bool? isActive,
    bool? lowStock,
    int? limit,
    int? offset,
    bool includeDeleted = false,
  }) async {
    final db = await _databaseService.database;
    
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (!includeDeleted) {
      whereClauses.add('p.${DatabaseConstants.columnIsDeleted} = 0');
    }
    if (isActive != null) {
      whereClauses.add('p.${DatabaseConstants.columnIsActive} = ?');
      whereArgs.add(isActive ? 1 : 0);
    }
    if (categoryId != null) {
      whereClauses.add('pc.category_id = ?');
      whereArgs.add(categoryId);
    }
    if (supplierId != null) {
      whereClauses.add('p.${DatabaseConstants.columnSupplierId} = ?');
      whereArgs.add(supplierId);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim()}%';
      whereClauses.add('(p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ?)');
      whereArgs.addAll([q, q, q]);
    }
    
    String joinInventory = ' LEFT JOIN ${DatabaseConstants.tableInventory} i ON p.id = i.product_id ';
    String having = '';
    if (lowStock == true) {
      having = ' HAVING COALESCE(SUM(i.quantity), 0) <= p.low_stock_threshold ';
    }

    final where = whereClauses.isEmpty ? '1=1' : whereClauses.join(' AND ');

    final results = await db.rawQuery('''
      SELECT p.*, pc.category_id, COALESCE(SUM(i.quantity), 0) as current_stock
      FROM ${DatabaseConstants.tableProducts} p
      LEFT JOIN ${DatabaseConstants.tableProductCategories} pc ON p.id = pc.product_id
      $joinInventory
      WHERE $where
      GROUP BY p.id
      $having
      ORDER BY p.name ASC
      LIMIT ? OFFSET ?
    ''', [...whereArgs, limit ?? 50, offset ?? 0]);

    return results.map((e) => Product.fromJson(e)).toList();
  }

  /// Counts products for pagination.
  Future<int> count({
    String? searchQuery,
    String? categoryId,
    bool? isActive,
    bool includeDeleted = false,
  }) async {
    final db = await _databaseService.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (!includeDeleted) whereClauses.add('p.${DatabaseConstants.columnIsDeleted} = 0');
    if (isActive != null) {
      whereClauses.add('p.${DatabaseConstants.columnIsActive} = ?');
      whereArgs.add(isActive ? 1 : 0);
    }
    if (categoryId != null) {
      whereClauses.add('pc.category_id = ?');
      whereArgs.add(categoryId);
    }

    final where = whereClauses.isEmpty ? '1=1' : whereClauses.join(' AND ');
    final r = await db.rawQuery('''
      SELECT COUNT(DISTINCT p.id) FROM ${DatabaseConstants.tableProducts} p
      LEFT JOIN ${DatabaseConstants.tableProductCategories} pc ON p.id = pc.product_id
      WHERE $where
    ''', whereArgs);
    
    return Sqflite.firstIntValue(r) ?? 0;
  }
}
