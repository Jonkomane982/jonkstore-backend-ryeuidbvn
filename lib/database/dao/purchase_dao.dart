import 'package:sqflite/sqflite.dart';
import '../database_service.dart';
import '../database_constants.dart';
import '../../core/domain/models/purchase_order.dart';
import '../../core/domain/models/purchase_order_item.dart';

/// Data Access Object for Purchase Orders and their items.
/// 
/// Handles atomic transactions for creating orders and updating status,
/// with joins for supplier and product details.
class PurchaseDao {
  final DatabaseService _databaseService;

  PurchaseDao(this._databaseService);

  /// Inserts a purchase order, its items, and fee allocations within a transaction.
  Future<void> insertOrder(
    PurchaseOrder order, 
    List<PurchaseOrderItem> items, 
    {Map<String, double>? runnerFeeAllocations, Transaction? txn}
  ) async {
    final executor = txn ?? await _databaseService.database;
    
    await executor.insert(
      DatabaseConstants.tablePurchaseOrders,
      order.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    for (final item in items) {
      await executor.insert(
        DatabaseConstants.tablePurchaseOrderItems,
        item.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Store runner fee allocation if provided
      if (runnerFeeAllocations != null && runnerFeeAllocations.containsKey(item.productId)) {
        await executor.insert(
          DatabaseConstants.tableRunnerFeeAllocations,
          {
            'id': '${item.id}_fee',
            'runner_fee_id': order.id, // Using PO ID as the link for simplicity if runner_fees table not fully used
            'purchase_order_item_id': item.id,
            'allocated_amount': runnerFeeAllocations[item.productId],
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  /// Updates a purchase order's status and metadata.
  Future<void> updateStatus(String orderId, String status, {Transaction? txn}) async {
    final executor = txn ?? await _databaseService.database;
    await executor.update(
      DatabaseConstants.tablePurchaseOrders,
      {
        DatabaseConstants.columnStatus: status.toUpperCase(),
        DatabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.columnSyncStatus: 'UPDATED',
      },
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [orderId],
    );
  }

  /// Finds a specific purchase order by ID.
  Future<PurchaseOrder?> findById(String id) async {
    final db = await _databaseService.database;
    final results = await db.rawQuery('''
      SELECT po.*, s.${DatabaseConstants.columnName} as supplier_name 
      FROM ${DatabaseConstants.tablePurchaseOrders} po
      JOIN ${DatabaseConstants.tableSuppliers} s ON po.${DatabaseConstants.columnSupplierId} = s.${DatabaseConstants.columnId}
      WHERE po.${DatabaseConstants.columnId} = ?
    ''', [id]);
    
    return results.isNotEmpty ? PurchaseOrder.fromJson(results.first) : null;
  }

  /// Retrieves all items for a specific purchase order with product details and fee allocations.
  Future<List<Map<String, dynamic>>> getOrderItemsWithDetails(String orderId) async {
    final db = await _databaseService.database;
    return await db.rawQuery('''
      SELECT 
        poi.*, 
        p.${DatabaseConstants.columnName} as product_name, 
        p.${DatabaseConstants.columnBarcode} as barcode,
        rfa.allocated_amount as runner_fee_allocation
      FROM ${DatabaseConstants.tablePurchaseOrderItems} poi
      JOIN ${DatabaseConstants.tableProducts} p ON poi.${DatabaseConstants.columnProductId} = p.id
      LEFT JOIN ${DatabaseConstants.tableRunnerFeeAllocations} rfa ON poi.id = rfa.purchase_order_item_id
      WHERE poi.purchase_order_id = ?
    ''', [orderId]);
  }

  /// Retrieves purchase orders with supplier info for list views.
  Future<List<Map<String, dynamic>>> findAllWithSupplierInfo({
    String? branchId,
    String? status,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    final db = await _databaseService.database;
    
    String query = '''
      SELECT po.*, s.${DatabaseConstants.columnName} as supplier_name, s.${DatabaseConstants.columnCode} as supplier_code
      FROM ${DatabaseConstants.tablePurchaseOrders} po
      JOIN ${DatabaseConstants.tableSuppliers} s ON po.${DatabaseConstants.columnSupplierId} = s.${DatabaseConstants.columnId}
      WHERE po.${DatabaseConstants.columnIsDeleted} = 0
    ''';
    
    List<dynamic> args = [];
    if (branchId != null) {
      query += ' AND po.${DatabaseConstants.columnBranchId} = ?';
      args.add(branchId);
    }
    
    if (status != null) {
      query += ' AND po.${DatabaseConstants.columnStatus} = ?';
      args.add(status.toUpperCase());
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim()}%';
      query += ' AND (po.${DatabaseConstants.columnOrderNumber} LIKE ? OR s.${DatabaseConstants.columnName} LIKE ?)';
      args.addAll([q, q]);
    }
    
    query += ' ORDER BY po.${DatabaseConstants.columnCreatedAt} DESC';
    
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

  /// Calculates total investment in purchase orders for a branch.
  Future<double> getTotalInvestment(String branchId) async {
    final db = await _databaseService.database;
    final result = await db.rawQuery('''
      SELECT SUM(${DatabaseConstants.columnTotalAmount}) as total_investment
      FROM ${DatabaseConstants.tablePurchaseOrders}
      WHERE ${DatabaseConstants.columnBranchId} = ? 
        AND ${DatabaseConstants.columnIsDeleted} = 0
        AND ${DatabaseConstants.columnStatus} != 'CANCELLED'
    ''', [branchId]);
    
    return (result.first['total_investment'] as num?)?.toDouble() ?? 0.0;
  }

  /// Retrieves typed purchase order items for a specific order.
  Future<List<PurchaseOrderItem>> getOrderItems(String orderId) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      DatabaseConstants.tablePurchaseOrderItems,
      where: '${DatabaseConstants.columnPurchaseOrderId} = ?',
      whereArgs: [orderId],
    );
    return rows.map((row) => PurchaseOrderItem.fromJson(row)).toList();
  }
}
