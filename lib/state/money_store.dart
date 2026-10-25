import 'package:flutter/foundation.dart';

import '../core/categories.dart';
import '../data/models.dart';
import '../data/storage.dart';

/// Income and spend totals for a period.
class FlowSummary {
  const FlowSummary(this.incomeMinor, this.expenseMinor);

  final int incomeMinor;
  final int expenseMinor;

  int get netMinor => incomeMinor - expenseMinor;

  /// Share of income kept, 0..1 (null when there was no income).
  double? get savingsRate => incomeMinor <= 0 ? null : netMinor / incomeMinor;
}

class _Snapshot {
  const _Snapshot(this.buckets, this.txns);

  final List<Bucket> buckets;
  final List<Txn> txns;
}

/// Owns buckets and the ledger. Every mutation goes through here, is
/// persisted, and can be undone once.
class MoneyStore extends ChangeNotifier {
  MoneyStore(this._storage) {
    final loaded = _storage.loadLedger();
    if (loaded == null) {
      _buckets = defaultBuckets();
      _txns = [];
      _persist();
    } else {
      _buckets = loaded.buckets;
      _txns = loaded.txns;
      _sortTxns();
    }
    _recompute();
  }

  final Storage _storage;

  List<Bucket> _buckets = [];
  List<Txn> _txns = [];
  Map<String, int> _balances = {};
  _Snapshot? _undo;

  static List<Bucket> defaultBuckets() => [
        Bucket(id: newId(), name: 'Usable Money', emoji: '💳', colorValue: bucketColors[0].toARGB32()),
        Bucket(id: newId(), name: 'Invested Money', emoji: '📈', colorValue: bucketColors[2].toARGB32()),
      ];

  // ---------------------------------------------------------------- queries

  List<Bucket> get buckets => List.unmodifiable(_buckets);

  /// All transactions, newest first.
  List<Txn> get txns => List.unmodifiable(_txns);

  Bucket? bucket(String? id) {
    for (final b in _buckets) {
      if (b.id == id) return b;
    }
    return null;
  }

  int balanceOf(String bucketId) => _balances[bucketId] ?? 0;

  int get totalBalance =>
      _buckets.where((b) => b.includeInTotal).fold(0, (s, b) => s + balanceOf(b.id));

  int get excludedCount => _buckets.where((b) => !b.includeInTotal).length;

  bool get canUndo => _undo != null;

  List<Txn> txnsForBucket(String bucketId) =>
      _txns.where((t) => t.legs.any((l) => l.bucketId == bucketId)).toList();

  List<Txn> txnsInMonth(DateTime month) =>
      _txns.where((t) => t.date.year == month.year && t.date.month == month.month).toList();

  FlowSummary summaryFor(Iterable<Txn> txns) {
    var income = 0;
    var expense = 0;
    for (final t in txns) {
      if (t.type == TxnType.income) income += t.amountMinor;
      if (t.type == TxnType.expense) expense += t.amountMinor;
    }
    return FlowSummary(income, expense);
  }

  FlowSummary monthSummary(DateTime month) => summaryFor(txnsInMonth(month));

  /// Money in/out of one bucket in a month, ignoring balance adjustments.
  FlowSummary bucketMonthFlow(String bucketId, DateTime month) {
    var inflow = 0;
    var outflow = 0;
    for (final t in txnsInMonth(month)) {
      if (t.type == TxnType.adjustment) continue;
      final d = t.deltaFor(bucketId);
      if (d > 0) inflow += d;
      if (d < 0) outflow -= d;
    }
    return FlowSummary(inflow, outflow);
  }

  /// Spend per category for a month, largest first.
  List<MapEntry<String, int>> spendByCategory(DateTime month) {
    final map = <String, int>{};
    for (final t in txnsInMonth(month)) {
      if (t.type != TxnType.expense) continue;
      final id = t.categoryId ?? 'other';
      map[id] = (map[id] ?? 0) + t.amountMinor;
    }
    return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  // -------------------------------------------------------------- mutations

  Bucket addBucket({
    required String name,
    required String emoji,
    required int colorValue,
    bool includeInTotal = true,
    int? goalMinor,
    int openingMinor = 0,
  }) {
    _snapshot();
    final b = Bucket(
      id: newId(),
      name: name.trim(),
      emoji: emoji,
      colorValue: colorValue,
      includeInTotal: includeInTotal,
      goalMinor: goalMinor,
    );
    _buckets = [..._buckets, b];
    if (openingMinor != 0) {
      _txns.add(Txn(
        id: newId(),
        type: TxnType.adjustment,
        date: DateTime.now(),
        legs: [TxnLeg(b.id, openingMinor)],
        note: 'Opening balance',
      ));
      _sortTxns();
    }
    _commit();
    return b;
  }

  void updateBucket(Bucket updated) {
    _snapshot();
    _buckets = [for (final b in _buckets) b.id == updated.id ? updated : b];
    _commit();
  }

  void toggleInclude(String id) {
    final b = bucket(id);
    if (b == null) return;
    updateBucket(b.copyWith(includeInTotal: !b.includeInTotal));
  }

  /// Removes the bucket and its side of every transaction. Transactions left
  /// with no legs disappear; other buckets' balances are untouched.
  void deleteBucket(String id) {
    _snapshot();
    _buckets = [
      for (final b in _buckets)
        if (b.id != id)
          b.defaultSplit.containsKey(id)
              ? b.copyWith(defaultSplit: Map.of(b.defaultSplit)..remove(id))
              : b,
    ];
    _txns = [
      for (final t in _txns)
        if (t.legs.any((l) => l.bucketId != id))
          t.legs.any((l) => l.bucketId == id)
              ? t.copyWith(legs: t.legs.where((l) => l.bucketId != id).toList())
              : t,
    ];
    _commit();
  }

  void reorderBuckets(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    _snapshot();
    final list = [..._buckets];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), item);
    _buckets = list;
    _commit();
  }

  /// Deposit [amountMinor] into [bucketId], optionally sending [shares]
  /// (target id → minor units) to other buckets. The remainder stays.
  Txn addIncome({
    required String bucketId,
    required int amountMinor,
    Map<String, int> shares = const {},
    Map<String, int>? rememberSplitBp,
    String categoryId = 'salary',
    String note = '',
    DateTime? date,
  }) {
    _checkPositive(amountMinor);
    final sent = _checkShares(bucketId, amountMinor, shares);
    _snapshot();
    final legs = <TxnLeg>[
      // Always keep the receiving bucket's leg so the entry shows in its history.
      TxnLeg(bucketId, amountMinor - sent),
      for (final e in shares.entries)
        if (e.value > 0) TxnLeg(e.key, e.value),
    ];
    final t = Txn(
      id: newId(),
      type: TxnType.income,
      date: date ?? DateTime.now(),
      legs: legs,
      categoryId: categoryId,
      note: note.trim(),
    );
    _txns.add(t);
    _rememberSplit(bucketId, rememberSplitBp);
    _sortTxns();
    _commit();
    return t;
  }

  /// Records one expense per item from [bucketId]; they share a group id.
  List<Txn> addExpenses({
    required String bucketId,
    required List<ExpenseItem> items,
    DateTime? date,
  }) {
    final valid = items.where((i) => i.amountMinor > 0).toList();
    if (valid.isEmpty) throw ArgumentError('Enter at least one amount');
    if (bucket(bucketId) == null) throw ArgumentError('Unknown bucket');
    _snapshot();
    final when = date ?? DateTime.now();
    final group = valid.length > 1 ? newId() : null;
    final created = <Txn>[];
    for (var i = 0; i < valid.length; i++) {
      final item = valid[i];
      created.add(Txn(
        id: newId(),
        type: TxnType.expense,
        // Keep entry order stable inside the group.
        date: when.subtract(Duration(milliseconds: i)),
        legs: [TxnLeg(bucketId, -item.amountMinor)],
        categoryId: item.categoryId,
        note: item.note.trim(),
        groupId: group,
      ));
    }
    _txns.addAll(created);
    _sortTxns();
    _commit();
    return created;
  }

  /// Moves [shares] (target id → minor units) out of [fromId].
  Txn transfer({
    required String fromId,
    required Map<String, int> shares,
    Map<String, int>? rememberSplitBp,
    String note = '',
    DateTime? date,
  }) {
    final total = shares.values.fold(0, (s, v) => s + v);
    _checkPositive(total);
    _checkShares(fromId, total, shares);
    _snapshot();
    final t = Txn(
      id: newId(),
      type: TxnType.transfer,
      date: date ?? DateTime.now(),
      legs: [
        TxnLeg(fromId, -total),
        for (final e in shares.entries)
          if (e.value > 0) TxnLeg(e.key, e.value),
      ],
      note: note.trim(),
    );
    _txns.add(t);
    _rememberSplit(fromId, rememberSplitBp);
    _sortTxns();
    _commit();
    return t;
  }

  /// Sets a bucket's balance to [newBalanceMinor] by recording the difference.
  Txn? adjustBalance(String bucketId, int newBalanceMinor, {String note = 'Balance adjusted'}) {
    final delta = newBalanceMinor - balanceOf(bucketId);
    if (delta == 0) return null;
    _snapshot();
    final t = Txn(
      id: newId(),
      type: TxnType.adjustment,
      date: DateTime.now(),
      legs: [TxnLeg(bucketId, delta)],
      note: note,
    );
    _txns.add(t);
    _sortTxns();
    _commit();
    return t;
  }

  void deleteTxn(String id) {
    _snapshot();
    _txns = _txns.where((t) => t.id != id).toList();
    _commit();
  }

  /// Restores the state before the last mutation.
  bool undo() {
    final s = _undo;
    if (s == null) return false;
    _buckets = s.buckets;
    _txns = s.txns;
    _undo = null;
    _commit();
    return true;
  }

  void resetAll() {
    _snapshot();
    _buckets = defaultBuckets();
    _txns = [];
    _commit();
  }

  String exportJson() => Storage.encodeLedger(_buckets, _txns, pretty: true);

  /// Replaces everything with a backup. Throws [FormatException] when invalid.
  void importJson(String raw) {
    final doc = Storage.decodeLedger(raw);
    _snapshot();
    _buckets = doc.buckets;
    _txns = doc.txns;
    _sortTxns();
    _commit();
  }

  String exportCsv() {
    String esc(String s) => s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
    final rows = <String>['date,type,bucket,amount,category,note'];
    for (final t in _txns) {
      for (final l in t.legs) {
        rows.add([
          t.date.toIso8601String(),
          t.type.name,
          esc(bucket(l.bucketId)?.name ?? '?'),
          (l.amountMinor / 100).toStringAsFixed(2),
          esc(t.categoryId == null ? '' : categoryById(t.categoryId).name),
          esc(t.note),
        ].join(','));
      }
    }
    return rows.join('\n');
  }

  // ---------------------------------------------------------------- helpers

  void _checkPositive(int amountMinor) {
    if (amountMinor <= 0) throw ArgumentError('Enter an amount greater than zero');
  }

  /// Validates split shares and returns their total.
  int _checkShares(String sourceId, int amountMinor, Map<String, int> shares) {
    if (bucket(sourceId) == null) throw ArgumentError('Unknown bucket');
    var sum = 0;
    for (final e in shares.entries) {
      if (e.value < 0) throw ArgumentError('Shares cannot be negative');
      if (e.key == sourceId) throw ArgumentError('Cannot split into the same bucket');
      if (bucket(e.key) == null) throw ArgumentError('Unknown bucket');
      sum += e.value;
    }
    if (sum > amountMinor) throw ArgumentError('Split is more than the amount');
    return sum;
  }

  void _rememberSplit(String bucketId, Map<String, int>? bp) {
    if (bp == null) return;
    final b = bucket(bucketId);
    if (b == null) return;
    final cleaned = Map<String, int>.fromEntries(bp.entries.where((e) => e.value > 0));
    _buckets = [for (final x in _buckets) x.id == bucketId ? b.copyWith(defaultSplit: cleaned) : x];
  }

  void _snapshot() => _undo = _Snapshot(List.of(_buckets), List.of(_txns));

  void _sortTxns() => _txns.sort((a, b) => b.date.compareTo(a.date));

  void _recompute() {
    final map = <String, int>{};
    for (final t in _txns) {
      for (final l in t.legs) {
        map[l.bucketId] = (map[l.bucketId] ?? 0) + l.amountMinor;
      }
    }
    _balances = map;
  }

  void _commit() {
    _recompute();
    _persist();
    notifyListeners();
  }

  void _persist() => _storage.saveLedger(_buckets, _txns);
}
