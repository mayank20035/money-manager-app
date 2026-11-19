import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/app.dart';
import 'package:money_manager/data/models.dart';
import 'package:money_manager/data/storage.dart';
import 'package:money_manager/state/money_store.dart';
import 'package:money_manager/state/settings_store.dart';
import 'package:money_manager/ui/insights/bucket_flow.dart';
import 'package:money_manager/ui/insights/insights_screen.dart';
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

  testWidgets('tapping the spending donut never breaks the insights card', (tester) async {
    final money = await pumpApp(tester);
    final usable = money.buckets.first;
    money.addIncome(bucketId: usable.id, amountMinor: 500000);
    money.addExpenses(bucketId: usable.id, items: const [
      ExpenseItem(amountMinor: 120000, categoryId: 'transport'),
      ExpenseItem(amountMinor: 45000, categoryId: 'food'),
    ]);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Insights')));
    await tester.pumpAndSettle();

    final donut = find.byType(PieChart);
    await tester.ensureVisible(donut);
    await tester.pumpAndSettle();

    final box = tester.getRect(donut);
    // Taps outside the ring (the hole, or the empty space beside it) report
    // slice index -1, which used to crash the card.
    for (final spot in [box.center, Offset(box.left + 10, box.center.dy)]) {
      await tester.tapAt(spot);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Total spent'), findsOneWidget);
    }

    // A slice focuses its category (the ring spans radius 62..88)…
    await tester.tapAt(box.center - const Offset(0, 75));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Total spent'), findsNothing);

    // …and tapping the middle clears it again.
    await tester.tapAt(box.center);
    await tester.pumpAndSettle();
    expect(find.text('Total spent'), findsOneWidget);
  });

  testWidgets('bucket flow shows each bucket and expands into a breakdown', (tester) async {
    final money = await pumpApp(tester);
    final [usable, invested] = money.buckets;
    money.addIncome(bucketId: usable.id, amountMinor: 5000000, shares: {invested.id: 1500000});
    money.addExpenses(bucketId: usable.id, items: const [ExpenseItem(amountMinor: 120000, categoryId: 'transport')]);
    money.transfer(fromId: usable.id, shares: {invested.id: 100000});
    money.adjustBalance(invested.id, money.balanceOf(invested.id) + 50000);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Insights')));
    await tester.pumpAndSettle();
    // Insights builds lazily: scroll its list to reach the section.
    final list = find.descendant(of: find.byType(InsightsScreen), matching: find.byType(Scrollable)).first;
    final section = find.byType(BucketFlowSection);
    await tester.scrollUntilVisible(section, 250, scrollable: list);
    await tester.pumpAndSettle();

    expect(find.text('Spent the most'), findsOneWidget);
    // Later highlight cards sit off-screen in the sideways list.
    expect(find.text('Grew the most', skipOffstage: false), findsOneWidget);
    expect(find.text('Biggest move', skipOffstage: false), findsOneWidget);
    expect(find.text('CAME IN'), findsNothing);
    // The adjustment is named on Invested Money's row.
    expect(find.text(' adjusted', skipOffstage: false), findsOneWidget);

    // Expand Usable Money.
    final usableRow = find.descendant(of: section, matching: find.text('Usable Money'));
    await tester.scrollUntilVisible(usableRow, 150, scrollable: list);
    await tester.tap(usableRow);
    await tester.pumpAndSettle();
    expect(find.text('CAME IN'), findsOneWidget);
    expect(find.text('WENT OUT'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('To Invested Money'), findsOneWidget);
    expect(find.text('Open Usable Money'), findsOneWidget);
    expect(find.byType(LineChart), findsWidgets);

    // Week and year views work, and an empty past year says so.
    for (final (kind, label) in [('Week', 'This week'), ('Year', 'This year')]) {
      await tester.scrollUntilVisible(find.text(kind), -300, scrollable: list);
      await tester.tap(find.text(kind));
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byTooltip('Previous year'));
    await tester.pumpAndSettle();
    expect(find.text('Last year'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('No bucket activity this year'), 250, scrollable: list);
    expect(tester.takeException(), isNull);
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
