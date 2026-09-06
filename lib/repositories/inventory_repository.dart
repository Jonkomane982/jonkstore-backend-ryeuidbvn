import '../core/domain/models/inventory.dart';
import '../core/domain/models/inventory_transaction.dart';
import '../core/domain/models/inventory_adjustment.dart';
import '../core/domain/models/inventory_count.dart';
import '../core/domain/models/stock_transfer.dart';
import '../core/network/result.dart';

/// Interface for Inventory repository operations.
/// 
/// The authoritative source for stock levels and movements across all branches.
abstract class InventoryRepository {
  // --- Inventory Core ---
  Future<Result<Inventory>> upsertInventory(Inventory inventory);
  Future<Result<Inventory?>> findByProductId(String productId, String branchId);
  Future<Result<Inventory?>> findByBarcode(String barcode, String branchId);
  Future<Result<List<Inventory>>> findAll({
    String? branchId,
    bool lowStockOnly = false,
    bool outOfStockOnly = false,
    String? searchQuery,
    String? categoryId,
    String? supplierId,
    int? limit,
    int? offset,
  });
  Stream<List<Inventory>> watchInventory(String branchId);

  // --- Stock Movements & History ---
  Future<Result<void>> processStockMovement({
    required String inventoryId,
    required double newQuantity,
    required InventoryTransaction transaction,
  });
  Future<Result<void>> recordTransaction(InventoryTransaction transaction);
  Future<Result<List<InventoryTransaction>>> getTransactionHistory(String inventoryId);
  Future<Result<List<InventoryTransaction>>> getProductHistory(String productId);

  // --- Adjustments, Counts & Transfers ---
  Future<Result<void>> createAdjustment(InventoryAdjustment adjustment, List<InventoryTransaction> transactions);
  Future<Result<void>> createStockCount(InventoryCount count, List<InventoryTransaction> transactions);
  Future<Result<void>> createStockTransfer(StockTransfer transfer, List<InventoryTransaction> transactions);
  Future<Result<List<StockTransfer>>> getStockTransfers();
  
  // --- Valuation ---
  Future<Result<double>> getInventoryValuation(String branchId);
  
  // --- Sync ---
  Future<Result<void>> sync();
}
