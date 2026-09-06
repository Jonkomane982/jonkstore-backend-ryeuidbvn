/// Represents the current stage of a Purchase Order lifecycle.
enum PurchaseStatus {
  /// Initial state, order is being prepared.
  draft,

  /// Order has been sent to the supplier.
  ordered,

  /// Some items have been received, but not all.
  partial,

  /// All items have been fully received into inventory.
  received,

  /// Order has been cancelled.
  cancelled,
}

extension PurchaseStatusX on PurchaseStatus {
  String get value => name.toUpperCase();

  static PurchaseStatus fromValue(String value) {
    return PurchaseStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => PurchaseStatus.draft,
    );
  }
}
