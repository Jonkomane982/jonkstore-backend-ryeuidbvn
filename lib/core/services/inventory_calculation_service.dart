import 'package:jonkstore/core/domain/models/inventory.dart';
import 'package:jonkstore/core/domain/models/product.dart';

/// Service responsible for authoritative inventory calculations.
/// 
/// Enforces business rules for stock valuation and availability 
/// based on the commercial-grade cost methodology.
class InventoryCalculationService {
  /// Calculates the total value of stock for a set of inventory records.
  /// 
  /// Valuation is derived from (Quantity * Cost Price).
  /// Selling price is never used for inventory valuation.
  double calculateInventoryValue(List<Inventory> inventoryItems, Map<String, Product> productMap) {
    return inventoryItems.fold(0.0, (sum, item) {
      final product = productMap[item.productId];
      final cost = product?.costPrice ?? 0.0;
      return sum + (item.quantity * cost);
    });
  }

  /// Calculates the available stock for sale.
  /// 
  /// Available = Current Physical Quantity - Reserved Quantity.
  double calculateAvailableStock(Inventory inventory) {
    return (inventory.quantity - inventory.reservedQuantity).clamp(0.0, double.infinity);
  }

  /// Determines the status of an inventory item.
  String determineStockStatus(Inventory inventory) {
    if (inventory.quantity <= 0) return 'OUT_OF_STOCK';
    if (inventory.quantity <= inventory.lowStockThreshold) return 'LOW_STOCK';
    return 'IN_STOCK';
  }
}
