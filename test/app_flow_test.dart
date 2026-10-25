import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app.dart';
import 'package:money_manager/data/storage.dart';
import 'package:money_manager/state/money_store.dart';
import 'package:money_manager/state/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<MoneyStore> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final storage = Storage(await SharedPreferences.getInstance());
  final money = MoneyStore(storage);
  await tester.pumpWidget(MoneyApp(money: money, settings: SettingsStore(storage)));
  await tester.pumpAndSettle();
  return money;
}

Future<void> tapKeys(WidgetTester tester, String keys) async {
  for (final k in keys.split('')) {
    await tester.tap(find.descendant(of: find.byType(InkWell), matching: find.text(k)).last);
    await tester.pump();
  }
}

void main() {
  testWidgets('add money with the calculator keypad, then undo', (tester) async {
    final money = await pumpApp(tester);
    expect(find.text('Usable Money'), findsOneWidget);
    expect(find.text('Invested Money'), findsOneWidget);

    await tester.tap(find.byTooltip('Add to Usable Money'));
    await tester.pumpAndSettle();

    await tapKeys(tester, '1200+300');
    expect(find.text('= ₹1,500.00'), findsOneWidget);

    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();

    final usable = money.buckets.first;
    expect(money.balanceOf(usable.id), 150000);
    expect(find.textContaining('Added ₹1,500.00'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(money.balanceOf(usable.id), 0);
  });

  testWidgets('undo snack bar dismisses itself', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Add to Usable Money'));
    await tester.pumpAndSettle();
    await tapKeys(tester, '5');
    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('transfer is blocked when the source has no money', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Transfer').first);
    await tester.pumpAndSettle();
    await tapKeys(tester, '50');
    await tester.pump();
    expect(find.textContaining('Only ₹0.00 available'), findsOneWidget);
  });

  testWidgets('create a bucket with a goal and opening balance', (tester) async {
    final money = await pumpApp(tester);
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Goa trip');
    await tester.enterText(find.widgetWithText(TextField, 'Savings goal (optional)'), '20000');
    await tester.enterText(find.widgetWithText(TextField, 'Current balance (optional)'), '5000');
    await tester.pump();
    await tester.tap(find.text('Create bucket'));
    await tester.pumpAndSettle();

    final trip = money.buckets.last;
    expect(trip.name, 'Goa trip');
    expect(trip.goalMinor, 2000000);
    expect(money.balanceOf(trip.id), 500000);
    expect(find.text('25% of ₹20,000'), findsOneWidget);
  });

  testWidgets('all tabs render', (tester) async {
    await pumpApp(tester);
    for (final tab in ['Activity', 'Insights', 'Settings', 'Home']) {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
      await tester.pumpAndSettle();
    }
    expect(find.text('Your money'), findsOneWidget);
  });
}
