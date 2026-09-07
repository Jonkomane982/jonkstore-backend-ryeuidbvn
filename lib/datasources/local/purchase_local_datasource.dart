import 'package:sqflite/sqflite.dart';
import '../../core/domain/models/purchase_order.dart';
import '../../core/domain/models/purchase_order_item.dart';
import '../../database/dao/purchase_dao.dart';

/// Local data source for Purchase Order operations using SQLite DAO.
class PurchaseLocalDataSource {
  final PurchaseDao _dao;

  PurchaseLocalDataSource(this._dao);

  /// Inserts a purchase order and its items.
  /// 
  /// Optionally accepts [runnerFeeAllocations] to store landed cost distribution.
  Future<void> insertOrder(
    PurchaseOrder order, 
    List<PurchaseOrderItem> items, 
    {Map<String, double>? runnerFeeAllocations, Transaction? txn}
  ) async {
    await _dao.insertOrder(order, items, runnerFeeAllocations: runnerFeeAllocations, txn: txn);
  }

  Future<void> updateOrderStatus(String orderId, String status, {Transaction? txn}) async {
    await _dao.updateStatus(orderId, status, txn: txn);
  }

  Future<PurchaseOrder?> findById(String id) async {
    return await _dao.findById(id);
  }

  /// Retrieves and maps items for a specific purchase order.
  Future<List<PurchaseOrderItem>> getOrderItems(String orderId) async {
    // FIX: Changed from non-existent getOrderItems to getOrderItemsWithDetails
    final results = await _dao.getOrderItemsWithDetails(orderId);
    return results.map((json) => PurchaseOrderItem.fromJson(json)).toList();
  }

  Future<List<Map<String, dynamic>>> findAll({
    String? branchId,
    String? status,
    String? searchQuery,
  }) async {
    return await _dao.findAllWithSupplierInfo(
      branchId: branchId,
      status: status,
      searchQuery: searchQuery,
    );
  }

  Future<double> getTotalInvestment(String branchId) async {
    return await _dao.getTotalInvestment(branchId);
  }
}
