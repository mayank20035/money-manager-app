import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/categories.dart';
import '../../data/models.dart';
import '../../state/money_store.dart';
import '../../state/settings_store.dart';
import '../widgets/common.dart';
import 'txn_detail_sheet.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _search = TextEditingController();
  TxnType? _type;
  String? _bucketId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Txn t, MoneyStore store, String q) {
    if (_type != null && t.type != _type) return false;
    if (_bucketId != null && !t.legs.any((l) => l.bucketId == _bucketId)) return false;
    if (q.isEmpty) return true;
    final haystack = [
      t.note,
      if (t.categoryId != null) categoryById(t.categoryId).name,
      for (final l in t.legs) store.bucket(l.bucketId)?.name ?? '',
      (t.amountMinor / 100).toStringAsFixed(2),
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final fmt = context.watch<SettingsStore>().format;
    final hidden = context.watch<SettingsStore>().hideAmounts;
    final scheme = Theme.of(context).colorScheme;
    final q = _search.text.trim().toLowerCase();
    final list = store.txns.where((t) => _matches(t, store, q)).toList();

    // Group by calendar day (list is already newest first).
    final groups = <DateTime, List<Txn>>{};
    for (final t in list) {
      groups.putIfAbsent(DateTime(t.date.year, t.date.month, t.date.day), () => []).add(t);
    }
    final selectedBucket = store.bucket(_bucketId);

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search notes, categories, buckets…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(_search.clear),
                        ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final (type, label) in [
                    (null, 'All'),
                    (TxnType.expense, 'Spent'),
                    (TxnType.income, 'Added'),
                    (TxnType.transfer, 'Transfers'),
                    (TxnType.adjustment, 'Adjustments'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _type == type,
                        onSelected: (_) => setState(() => _type = type),
                      ),
                    ),
                  PopupMenuButton<String?>(
                    tooltip: 'Filter by bucket',
                    onSelected: (id) => setState(() => _bucketId = id == '' ? null : id),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: '', child: Text('All buckets')),
                      for (final b in store.buckets)
                        PopupMenuItem(value: b.id, child: Text('${b.emoji}  ${b.name}')),
                    ],
                    child: Chip(
                      avatar: Text(selectedBucket?.emoji ?? '🪣'),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(selectedBucket?.name ?? 'All buckets'),
                          const Icon(Icons.arrow_drop_down_rounded, size: 20),
                        ],
                      ),
                      backgroundColor: selectedBucket == null ? null : scheme.secondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (list.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: store.txns.isEmpty
                  ? const EmptyState(
                      emoji: '🧾',
                      title: 'Nothing here yet',
                      message: 'Every deposit, spend and transfer you make will be listed here.',
                    )
                  : const EmptyState(emoji: '🔍', title: 'No matches', message: 'Try a different search or filter.'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
              sliver: SliverList.list(
                children: [
                  for (final MapEntry(key: day, value: txns) in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                      child: Row(
                        children: [
                          Text(friendlyDay(day),
                              style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant)),
                          const Spacer(),
                          if (!hidden)
                            Text(
                              _daySummary(store, txns, fmt.format),
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (final t in txns)
                            Dismissible(
                              key: ValueKey(t.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: scheme.error,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                child: Icon(Icons.delete_outline_rounded, color: scheme.onError),
                              ),
                              onDismissed: (_) {
                                store.deleteTxn(t.id);
                                showUndoSnack(context, 'Entry deleted · balances restored');
                              },
                              child: TxnTile(t, onTap: () => showTxnDetail(context, t)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _daySummary(MoneyStore store, List<Txn> txns, String Function(int) format) {
    final s = store.summaryFor(txns);
    final parts = [
      if (s.incomeMinor > 0) '+${format(s.incomeMinor)}',
      if (s.expenseMinor > 0) '−${format(s.expenseMinor)}',
    ];
    return parts.join('  ');
  }
}
