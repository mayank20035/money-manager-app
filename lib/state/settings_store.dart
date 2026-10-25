import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/theme.dart';
import '../data/storage.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore(this._storage) {
    final j = _storage.loadSettings();
    _themeMode = ThemeMode.values.asNameMap()[j['theme']] ?? ThemeMode.system;
    _accent = Color((j['accent'] as num?)?.toInt() ?? accentChoices.first.toARGB32());
    _currency = Currency.byCode(j['currency'] as String?);
    _monthlyBudgetMinor = (j['budget'] as num?)?.toInt();
    _hideAmounts = (j['hide'] as bool?) ?? false;
    _haptics = (j['haptics'] as bool?) ?? true;
    _format = MoneyFormat(_currency);
  }

  final Storage _storage;

  late ThemeMode _themeMode;
  late Color _accent;
  late Currency _currency;
  int? _monthlyBudgetMinor;
  late bool _hideAmounts;
  late bool _haptics;
  late MoneyFormat _format;

  ThemeMode get themeMode => _themeMode;
  Color get accent => _accent;
  Currency get currency => _currency;
  MoneyFormat get format => _format;
  int? get monthlyBudgetMinor => _monthlyBudgetMinor;
  bool get hideAmounts => _hideAmounts;
  bool get haptics => _haptics;

  set themeMode(ThemeMode v) => _update(() => _themeMode = v);
  set accent(Color v) => _update(() => _accent = v);
  set monthlyBudgetMinor(int? v) => _update(() => _monthlyBudgetMinor = (v ?? 0) > 0 ? v : null);
  set hideAmounts(bool v) => _update(() => _hideAmounts = v);
  set haptics(bool v) => _update(() => _haptics = v);
  set currency(Currency v) => _update(() {
        _currency = v;
        _format = MoneyFormat(v);
      });

  void _update(VoidCallback change) {
    change();
    _storage.saveSettings({
      'theme': _themeMode.name,
      'accent': _accent.toARGB32(),
      'currency': _currency.code,
      if (_monthlyBudgetMinor != null) 'budget': _monthlyBudgetMinor,
      'hide': _hideAmounts,
      'haptics': _haptics,
    });
    notifyListeners();
  }
}
