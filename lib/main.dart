import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/storage.dart';
import 'state/money_store.dart';
import 'state/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = Storage(await SharedPreferences.getInstance());
  runApp(MoneyApp(money: MoneyStore(storage), settings: SettingsStore(storage)));
}
