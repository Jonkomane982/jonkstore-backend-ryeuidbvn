/// Defines how the runner fee is distributed across items in a purchase order.
enum RunnerFeeAllocationMethod {
  /// Distributed proportional to each item's share of the total buying cost.
  proportionalByCost,

  /// Distributed equally among all line items.
  equal,
}

extension RunnerFeeAllocationMethodX on RunnerFeeAllocationMethod {
  String get value => name;

  static RunnerFeeAllocationMethod fromValue(String value) {
    return RunnerFeeAllocationMethod.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RunnerFeeAllocationMethod.proportionalByCost,
    );
  }
}
