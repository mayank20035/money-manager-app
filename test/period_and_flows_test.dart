import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/period.dart';
import 'package:money_manager/data/models.dart';
import 'package:money_manager/data/storage.dart';
import 'package:money_manager/state/money_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Period', () {
    test('weeks start on Monday', () {
      // Thursday 19 Nov 2026.
      final w = Period.containing(PeriodKind.week, DateTime(2026, 11, 19, 15));
      expect(w.start, DateTime(2026, 11, 16));
      expect(w.end, DateTime(2026, 11, 23));
      expect(w.slots, hasLength(7));
      expect(w.slotOf(DateTime(2026, 11, 22, 23, 59)), 6);
      expect(w.label, '16 – 22 Nov 2026');
    });

    test('week labels across months and years', () {
      expect(Period.containing(PeriodKind.week, DateTime(2026, 12, 2)).label, '30 Nov – 6 Dec 2026');
      expect(Period.containing(PeriodKind.week, DateTime(2027, 1, 1)).label, '28 Dec 2026 – 3 Jan 2027');
    });

    test('months and years', () {
      final m = Period.containing(PeriodKind.month, DateTime(2026, 2, 10));
      expect(m.slots, hasLength(28));
      expect(m.shift(-2).label, 'December 2025');
      expect(m.daysElapsed, 28);

      final y = Period.containing(PeriodKind.year, DateTime(2026, 7, 4));
      expect(y.slots, hasLength(12));
      expect(y.slotOf(DateTime(2026, 7, 4)), 6);
      expect(y.end, DateTime(2027));
      expect(y.label, '2026');
    });

    test('switching kind keeps the moment being looked at', () {
      final march = Period.containing(PeriodKind.month, DateTime(2025, 3, 1));
      expect(march.as(PeriodKind.year), Period.containing(PeriodKind.year, DateTime(2025)));
      expect(Period.current(PeriodKind.week).as(PeriodKind.month), Period.current(PeriodKind.month));
      expect(Period.current(PeriodKind.month).relative, 'This month');
      expect(Period.current(PeriodKind.month).shift(-1).relative, 'Last month');
    });
  });

  group('bucketFlows', () {
    late MoneyStore s;
    late String usable, invested, trip;
    final month = Period.current(PeriodKind.month);
    final lastMonth = month.shift(-1);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      s = MoneyStore(Storage(await SharedPreferences.getInstance()));
      usable = s.buckets[0].id;
      invested = s.buckets[1].id;
      trip = s.addBucket(name: 'Trip', emoji: '🌴', colorValue: 0xFF06B6D4).id;

      // Last month: salary of 10,000 into Usable.
      s.addIncome(bucketId: usable, amountMinor: 1000000, date: lastMonth.start.add(const Duration(days: 2)));
      // This month: salary of 50,000 split 30% to Invested.
      s.addIncome(bucketId: usable, amountMinor: 5000000, shares: {invested: 1500000}, categoryId: 'salary');
      s.addExpenses(bucketId: usable, items: const [
        ExpenseItem(amountMinor: 120000, categoryId: 'transport'),
        ExpenseItem(amountMinor: 45000, categoryId: 'food'),
        ExpenseItem(amountMinor: 5000, categoryId: 'food'),
      ]);
      s.transfer(fromId: usable, shares: {trip: 200000, invested: 100000});
      s.adjustBalance(trip, 150000);
    });

    BucketFlow flowOf(String id, Period p) => s.bucketFlows(p).firstWhere((f) => f.bucketId == id);

    test('splits money in and out by kind', () {
      final u = flowOf(usable, month);
      expect(u.openingMinor, 1000000);
      expect(u.addedMinor, 3500000);
      expect(u.incomeBySource, {'salary': 3500000});
      expect(u.spentMinor, 170000);
      expect(u.spendByCategory, {'transport': 120000, 'food': 50000});
      expect(u.movedOutMinor, 300000);
      expect(u.movedTo, {trip: 200000, invested: 100000});
      expect(u.closingMinor, s.balanceOf(usable));
      expect(u.openingMinor + u.netMinor + u.adjustedMinor, u.closingMinor);

      final i = flowOf(invested, month);
      expect(i.addedMinor, 1500000);
      expect(i.movedInMinor, 100000);
      expect(i.movedFrom, {usable: 100000});
      expect(i.outflowMinor, 0);
    });

    test('adjustments are tracked separately but count in the balance', () {
      final t = flowOf(trip, month);
      expect(t.movedInMinor, 200000);
      expect(t.adjustedMinor, -50000);
      expect(t.closingMinor, 150000);
      expect(t.isQuiet, isFalse);
    });

    test('earlier periods only see what happened then', () {
      final u = flowOf(usable, lastMonth);
      expect(u.openingMinor, 0);
      expect(u.addedMinor, 1000000);
      expect(u.closingMinor, 1000000);
      expect(flowOf(invested, lastMonth).isQuiet, isTrue);
    });

    test('balance series ends at the closing balance', () {
      final series = s.balanceSeries(usable, month);
      expect(series, hasLength(month.slots.length));
      final today = series[month.slotOf(DateTime.now())];
      expect(today, s.balanceOf(usable));
      expect(series.first == null || series.first! >= 1000000, isTrue);

      final yearly = s.balanceSeries(usable, Period.current(PeriodKind.year));
      expect(yearly.whereType<int>().last, s.balanceOf(usable));
    });
  });
}
