import 'package:intl/intl.dart';

/// A supported display currency. Amounts are always stored as integer
/// minor units (paise, cents), so switching currency only changes formatting.
class Currency {
  const Currency(this.code, this.symbol, this.name, this.locale);

  final String code;
  final String symbol;
  final String name;
  final String locale;

  static const all = [
    Currency('INR', '₹', 'Indian Rupee', 'en_IN'),
    Currency('USD', r'$', 'US Dollar', 'en_US'),
    Currency('EUR', '€', 'Euro', 'en_US'),
    Currency('GBP', '£', 'British Pound', 'en_GB'),
    Currency('AED', 'AED ', 'UAE Dirham', 'en_US'),
  ];

  static Currency byCode(String? code) =>
      all.firstWhere((c) => c.code == code, orElse: () => all.first);
}

/// Formats integer minor-unit amounts for display.
class MoneyFormat {
  MoneyFormat(this.currency)
      : _full = NumberFormat.currency(
          locale: currency.locale,
          symbol: currency.symbol,
          decimalDigits: 2,
        ),
        _whole = NumberFormat.currency(
          locale: currency.locale,
          symbol: currency.symbol,
          decimalDigits: 0,
        ),
        _compact = NumberFormat.compactCurrency(
          locale: currency.locale,
          symbol: currency.symbol,
          decimalDigits: 1,
        ),
        _number = NumberFormat.decimalPatternDigits(
          locale: currency.locale,
          decimalDigits: 2,
        );

  final Currency currency;
  final NumberFormat _full;
  final NumberFormat _whole;
  final NumberFormat _compact;
  final NumberFormat _number;

  static const mask = '••••••';

  /// `₹1,23,456.50`. Drops the `.00` when [dropZeroDecimals] and the amount is whole.
  String format(int minor, {bool signed = false, bool dropZeroDecimals = false}) {
    final value = minor.abs() / 100;
    final f = (dropZeroDecimals && minor % 100 == 0) ? _whole : _full;
    final body = f.format(value);
    if (minor < 0) return '−$body';
    if (signed && minor > 0) return '+$body';
    return body;
  }

  /// `₹1.2L` / `$4.5K` — for chart axes and tight spaces.
  String compact(int minor) {
    if (minor == 0) return '${currency.symbol}0';
    final body = _compact.format(minor.abs() / 100);
    return minor < 0 ? '−$body' : body;
  }

  /// Number without symbol: `1,23,456.50`.
  String number(int minor) => _number.format(minor / 100);

  String masked() => '${currency.symbol.trim()} $mask';
}

/// Parses user text such as `1,234.5` into minor units. Returns null when invalid.
int? parseMinor(String input) {
  final s = input.replaceAll(',', '').trim();
  if (s.isEmpty) return null;
  if (!RegExp(r'^\d+(\.\d{0,2})?$|^\.\d{1,2}$').hasMatch(s)) return null;
  final parts = s.split('.');
  final whole = parts[0].isEmpty ? 0 : int.parse(parts[0]);
  var frac = 0;
  if (parts.length > 1 && parts[1].isNotEmpty) {
    frac = int.parse(parts[1].padRight(2, '0'));
  }
  return whole * 100 + frac;
}

/// Minor units to an editable plain string (`1234.5` → `1234.50`, `1200` → `12`).
String minorToInput(int minor) {
  if (minor % 100 == 0) return (minor ~/ 100).toString();
  return (minor / 100).toStringAsFixed(2);
}
