import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/categories.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/money_store.dart';
import '../widgets/common.dart';

Future<void> showTxnDetail(BuildContext context, Txn txn) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TxnDetail(txn: txn),
  );
}

class _TxnDetail extends StatelessWidget {
  const _TxnDetail({required this.txn});

  final Txn txn;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final colors = MoneyColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final look = TxnLook(txn, store, colors);
    final typeLabel = switch (txn.type) {
      TxnType.income => 'Money added',
      TxnType.expense => 'Spent',
      TxnType.transfer => 'Transfer',
      TxnType.adjustment => 'Adjustment',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: look.tint.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(look.emoji, style: const TextStyle(fontSize: 30)),
            ),
          ),
          const SizedBox(height: 12),
          Text(look.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Center(
            child: MoneyText(
              txn.type == TxnType.expense ? -txn.amountMinor : txn.amountMinor,
              signed: txn.type != TxnType.transfer,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _row(context, 'Type', typeLabel),
                  _row(context, 'Date', DateFormat('EEE, d MMM yyyy · h:mm a').format(txn.date)),
                  if (txn.categoryId != null) _row(context, 'Category', categoryById(txn.categoryId).name),
                  if (txn.note.isNotEmpty) _row(context, 'Note', txn.note),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SectionHeader('Buckets affected'),
          Card(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            child: Column(
              children: [
                for (final l in txn.legs)
                  ListTile(
                    leading: store.bucket(l.bucketId) == null
                        ? const CircleAvatar(child: Text('?'))
                        : BucketAvatar(store.bucket(l.bucketId)!, size: 38),
                    title: Text(store.bucket(l.bucketId)?.name ?? 'Deleted bucket',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: MoneyText(
                      l.amountMinor,
                      signed: true,
                      color: l.amountMinor >= 0 ? colors.income : colors.expense,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () {
              store.deleteTxn(txn.id);
              showUndoSnack(context, 'Entry deleted · balances restored');
              Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete entry'),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
