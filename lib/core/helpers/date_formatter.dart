import 'package:intl/intl.dart';

/// Centralized date formatting utility for JonkStore POS.
class DateFormatter {
  static final DateFormat _dayMonthYear = DateFormat('dd MMM yyyy');
  static final DateFormat _fullDateTime = DateFormat('dd MMM yyyy, HH:mm');
  static final DateFormat _timeOnly = DateFormat('HH:mm');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');

  static String formatShortDate(DateTime date) => _dayMonthYear.format(date);
  static String formatFullDateTime(DateTime date) => _fullDateTime.format(date);
  static String formatTime(DateTime date) => _timeOnly.format(date);
  static String formatMonthYear(DateTime date) => _monthYear.format(date);

  /// Returns a human-readable "time ago" string.
  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return formatShortDate(date);
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
