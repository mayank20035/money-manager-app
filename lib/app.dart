import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'state/money_store.dart';
import 'state/settings_store.dart';
import 'ui/shell.dart';

class MoneyApp extends StatelessWidget {
  const MoneyApp({super.key, required this.money, required this.settings});

  final MoneyStore money;
  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: money),
        ChangeNotifierProvider.value(value: settings),
      ],
      child: Consumer<SettingsStore>(
        builder: (context, s, _) => MaterialApp(
          title: 'Money Manager',
          debugShowCheckedModeBanner: false,
          themeMode: s.themeMode,
          theme: buildTheme(s.accent, Brightness.light),
          darkTheme: buildTheme(s.accent, Brightness.dark),
          home: const Shell(),
        ),
      ),
    );
  }
}
