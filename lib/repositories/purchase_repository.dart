import '../core/domain/models/purchase_order.dart';
import '../core/domain/models/purchase_order_item.dart';
import '../core/network/result.dart';

/// Interface for Purchase repository operations.
/// 
/// Authoritative source for procurement workflow and cost tracking.
abstract class PurchaseRepository {
  Future<Result<PurchaseOrder>> createOrder(PurchaseOrder order, List<PurchaseOrderItem> items);
  
  Future<Result<PurchaseOrder>> updateOrder(PurchaseOrder order, List<PurchaseOrderItem> items);

  /// Updates the status of a purchase order (e.g., to 'ordered' or 'cancelled').
  Future<Result<PurchaseOrder>> updateStatus(String orderId, String status);

  /// Atomically receives stock from a purchase order.
  /// 
  /// Updates PO items with received quantities, updates inventory levels, 
  /// and creates inventory transactions.
  /// 
  /// If [isFinal] is true, the order status becomes 'received'.
  /// If false, it becomes 'partial' if any items are still pending.
  Future<Result<void>> receiveStock({
    required String orderId,
    required List<PurchaseOrderItem> receivedItems,
    bool isFinal = false,
  });

  Future<Result<PurchaseOrder?>> findById(String id);
  
  Future<Result<List<PurchaseOrder>>> findAll({
    String? branchId,
    String? status,
    String? searchQuery,
  });

  Future<Result<List<PurchaseOrderItem>>> getOrderItems(String orderId);
  
  Stream<List<PurchaseOrder>> watchOrders({String? branchId});
  
  Future<Result<double>> getTotalInvestment(String branchId);

  Future<Result<void>> sync();
}
