/// Categorizes the reason for an inventory quantity change.
enum InventoryTransactionType {
  /// Stock added through a purchase order.
  purchase,

  /// Stock reduced through a sale.
  sale,

  /// Manual correction of stock levels.
  adjustment,

  /// Stock returned by a customer.
  returnItem,

  /// Stock returned to a supplier.
  supplierReturn,

  /// Stock removed due to damage or expiration.
  damage,

  /// Stock change resulting from a physical count reconciliation.
  stockCount,

  /// Stock moved from another branch.
  transferIn,

  /// Stock moved to another branch.
  transferOut,
}
