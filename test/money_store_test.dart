import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/models.dart';
import 'package:money_manager/data/storage.dart';
import 'package:money_manager/state/money_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<MoneyStore> freshStore() async {
  SharedPreferences.setMockInitialValues({});
  return MoneyStore(Storage(await SharedPreferences.getInstance()));
}

void main() {
  test('first run creates the two original default buckets', () async {
    final s = await freshStore();
    expect(s.buckets.map((b) => b.name), ['Usable Money', 'Invested Money']);
    expect(s.totalBalance, 0);
  });

  test('income with split keeps the remainder in the source bucket', () async {
    final s = await freshStore();
    final [usable, invested] = s.buckets;
    s.addIncome(bucketId: usable.id, amountMinor: 100000, shares: {invested.id: 30000});
    expect(s.balanceOf(usable.id), 70000);
    expect(s.balanceOf(invested.id), 30000);
    expect(s.txns.single.amountMinor, 100000);
    expect(s.monthSummary(DateTime.now()).incomeMinor, 100000);
  });

  test('split larger than the amount is rejected', () async {
    final s = await freshStore();
    final [usable, invested] = s.buckets;
    expect(
      () => s.addIncome(bucketId: usable.id, amountMinor: 100, shares: {invested.id: 101}),
      throwsArgumentError,
    );
    expect(s.txns, isEmpty);
  });

  test('multi-item spend creates grouped entries and undo reverts all of them', () async {
    final s = await freshStore();
    final usable = s.buckets.first;
    s.addIncome(bucketId: usable.id, amountMinor: 50000);
    s.addExpenses(bucketId: usable.id, items: const [
      ExpenseItem(amountMinor: 12000, categoryId: 'food', note: 'Lunch'),
      ExpenseItem(amountMinor: 3000, categoryId: 'transport'),
      ExpenseItem(amountMinor: 0, categoryId: 'other'), // ignored
    ]);
    expect(s.balanceOf(usable.id), 35000);
    expect(s.txns.where((t) => t.type == TxnType.expense), hasLength(2));
    expect(s.spendByCategory(DateTime.now()).first.key, 'food');

    expect(s.undo(), isTrue);
    expect(s.balanceOf(usable.id), 50000);
    expect(s.canUndo, isFalse);
  });

  test('transfer moves money and deleting it reverses balances', () async {
    final s = await freshStore();
    final [usable, invested] = s.buckets;
    s.addIncome(bucketId: usable.id, amountMinor: 10000);
    final t = s.transfer(fromId: usable.id, shares: {invested.id: 4000});
    expect(s.balanceOf(usable.id), 6000);
    expect(s.balanceOf(invested.id), 4000);
    expect(s.totalBalance, 10000);

    s.deleteTxn(t.id);
    expect(s.balanceOf(usable.id), 10000);
    expect(s.balanceOf(invested.id), 0);
  });

  test('include-in-total filter', () async {
    final s = await freshStore();
    final [usable, invested] = s.buckets;
    s.addIncome(bucketId: usable.id, amountMinor: 100, shares: {invested.id: 40});
    s.toggleInclude(invested.id);
    expect(s.totalBalance, 60);
    expect(s.excludedCount, 1);
  });

  test('deleting the last bucket persists (bug in the original app)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = MoneyStore(Storage(prefs));
    for (final b in s.buckets) {
      s.deleteBucket(b.id);
    }
    expect(s.buckets, isEmpty);
    final reloaded = MoneyStore(Storage(prefs));
    expect(reloaded.buckets, isEmpty);
  });

  test('deleting a bucket keeps the other side of its transfers', () async {
    final s = await freshStore();
    final [usable, invested] = s.buckets;
    s.addIncome(bucketId: usable.id, amountMinor: 1000);
    s.transfer(fromId: usable.id, shares: {invested.id: 400});
    s.deleteBucket(usable.id);
    expect(s.balanceOf(invested.id), 400);
    expect(s.txns, hasLength(1));
  });

  test('opening balance and adjustments', () async {
    final s = await freshStore();
    final b = s.addBucket(name: 'Goa trip', emoji: '🌴', colorValue: 0xFF06B6D4, goalMinor: 2000000, openingMinor: 50000);
    expect(s.balanceOf(b.id), 50000);
    s.adjustBalance(b.id, 45000);
    expect(s.balanceOf(b.id), 45000);
    // Adjustments are not income or spend.
    expect(s.monthSummary(DateTime.now()).netMinor, 0);
  });

  test('remembers last split per bucket', () async {
    final s = await freshStore();
    final [usable, invested] = s.buckets;
    s.addIncome(
      bucketId: usable.id,
      amountMinor: 1000,
      shares: {invested.id: 200},
      rememberSplitBp: {invested.id: 2000},
    );
    expect(s.bucket(usable.id)!.defaultSplit, {invested.id: 2000});
  });

  test('export / import round trip', () async {
    final s = await freshStore();
    final usable = s.buckets.first;
    s.addIncome(bucketId: usable.id, amountMinor: 1234, note: 'Pay, "June"');
    final json = s.exportJson();
    expect(s.exportCsv(), contains('"Pay, ""June"""'));

    final other = await freshStore();
    other.importJson(json);
    expect(other.totalBalance, 1234);
    expect(() => other.importJson('{"nope":1}'), throwsFormatException);
  });
}
