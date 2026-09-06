import 'package:intl/intl.dart';

/// Centralized currency formatting utility for JonkStore POS.
class CurrencyFormatter {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
  );

  /// Formats a double to currency string (e.g., $1,234.56).
  static String format(double amount) => _currencyFormat.format(amount);

  /// Formats a string to currency string.
  static String formatString(String amount) {
    final doubleValue = double.tryParse(amount) ?? 0.0;
    return format(doubleValue);
  }

  /// Parses a currency string back to double.
  static double parse(String currencyString) {
    try {
      return _currencyFormat.parse(currencyString).toDouble();
    } catch (e) {
      return 0.0;
    }
  }
}
