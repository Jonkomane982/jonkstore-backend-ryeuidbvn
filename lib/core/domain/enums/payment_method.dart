/// Supported payment methods for sales and expenses.
enum PaymentMethod {
  /// Physical currency.
  cash,

  /// Credit or Debit card.
  card,

  /// Mobile money (Common in East Africa).
  mpesa,

  /// Direct bank transfer.
  bankTransfer,

  /// Any other method.
  other,
}
