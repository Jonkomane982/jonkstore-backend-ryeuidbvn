import '../domain/models/purchase_order_item.dart';

/// Business logic service for procurement-related calculations.
/// 
/// Strictly follows JonkStore POS business rules for Landed Cost 
/// and Runner Fee distribution.
class PurchaseCalculationService {
  
  /// Total Buying Cost = SUM(quantity × buying price)
  double calculateTotalBuyingCost(List<PurchaseOrderItem> items) {
    return items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitCost));
  }

  /// Alias for Total Buying Cost used for subtotaling in UI.
  double calculateBuyingSubtotal(List<PurchaseOrderItem> items) => calculateTotalBuyingCost(items);

  /// Total Investment = Total Buying Cost + Runner Fee
  double calculateTotalInvestment(double subtotal, double runnerFee) {
    return subtotal + runnerFee;
  }

  /// Proportional allocation based on item cost contribution.
  Map<String, double> calculateProportionalRunnerFeeAllocation(
    double runnerFee,
    List<PurchaseOrderItem> items,
  ) {
    final subtotal = calculateBuyingSubtotal(items);
    if (subtotal == 0) return {for (var item in items) item.id: 0.0};

    final Map<String, double> allocations = {};
    double distributedAmount = 0.0;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (i == items.length - 1) {
        // Rounding adjustment: last item gets the remainder to ensure exact match
        allocations[item.id] = double.parse((runnerFee - distributedAmount).toStringAsFixed(2));
      } else {
        final share = (item.quantity * item.unitCost) / subtotal;
        final allocation = double.parse((runnerFee * share).toStringAsFixed(2));
        allocations[item.id] = allocation;
        distributedAmount += allocation;
      }
    }
    return allocations;
  }

  /// Equal allocation across all items.
  Map<String, double> calculateEqualRunnerFeeAllocation(
    double runnerFee,
    List<PurchaseOrderItem> items,
  ) {
    if (items.isEmpty) return {};
    final Map<String, double> allocations = {};
    final share = double.parse((runnerFee / items.length).toStringAsFixed(2));
    double distributedAmount = 0.0;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (i == items.length - 1) {
        allocations[item.id] = double.parse((runnerFee - distributedAmount).toStringAsFixed(2));
      } else {
        allocations[item.id] = share;
        distributedAmount += share;
      }
    }
    return allocations;
  }

  /// Landed Unit Cost = (Buying Cost + Allocated Runner Fee) / Quantity
  double calculateLandedUnitCost(double unitCost, double quantity, double allocatedFee) {
    if (quantity == 0) return 0.0;
    final totalItemLandedCost = (unitCost * quantity) + allocatedFee;
    return double.parse((totalItemLandedCost / quantity).toStringAsFixed(2));
  }
}
