import 'package:intl/intl.dart';

/// Money/date formatting helpers shared by all screens.
class Fmt {
  static String symbol(String currency) => switch (currency) {
        'EUR' => '€',
        'GBP' => '£',
        'JPY' => '¥',
        'CAD' => r'CA$',
        'AUD' => r'A$',
        _ => r'$',
      };

  /// "$1,234.56" (absolute value; caller adds sign/color semantics).
  static String money(int cents, String currency) {
    final f = NumberFormat.currency(
        symbol: symbol(currency), decimalDigits: currency == 'JPY' ? 0 : 2);
    return f.format(cents.abs() / 100);
  }

  /// "+$120.00" / "−$45.00" for signed display.
  static String signedMoney(int cents, String currency) {
    final s = money(cents, currency);
    return cents < 0 ? '−$s' : '+$s';
  }

  /// Compact "$1.2K" for chart axes.
  static String moneyCompact(int cents, String currency) {
    final v = cents.abs() / 100;
    final f = NumberFormat.compactCurrency(
        symbol: symbol(currency), decimalDigits: 1);
    return f.format(v);
  }

  static String monthName(String month) {
    final d = DateTime(
        int.parse(month.substring(0, 4)), int.parse(month.substring(5, 7)));
    return DateFormat.yMMMM().format(d);
  }

  static String monthShort(String month) {
    final d = DateTime(
        int.parse(month.substring(0, 4)), int.parse(month.substring(5, 7)));
    return DateFormat.MMM().format(d);
  }

  static String dayLabel(String date) {
    final d = DateTime.parse(date);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat.MMMEd().format(d);
  }
}
