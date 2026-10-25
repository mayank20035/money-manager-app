import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/money_store.dart';
import '../../state/settings_store.dart';
import '../composer/composer_page.dart';
import '../history/txn_detail_sheet.dart';
import '../widgets/common.dart';
import 'bucket_editor_sheet.dart';

class BucketDetailPage extends StatelessWidget {
  const BucketDetailPage({super.key, required this.bucketId});

  final String bucketId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final b = store.bucket(bucketId);
    if (b == null) {
      // Deleted (possibly from the editor on this page).
      return Scaffold(appBar: AppBar(), body: const EmptyState(emoji: '🗑️', title: 'Bucket deleted'));
    }
    final colors = MoneyColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final balance = store.balanceOf(b.id);
    final flow = store.bucketMonthFlow(b.id, DateTime.now());
    final txns = store.txnsForBucket(b.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(b.name),
        actions: [
          IconButton(
            tooltip: 'Edit bucket',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              final deleted = await showBucketEditor(context, bucket: b);
              if (deleted && context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _Header(bucket: b, balance: balance),
          const SizedBox(height: 14),
          Row(
            children: [
              _Action(icon: Icons.add_rounded, label: 'Add', color: colors.income,
                  onTap: () => openComposer(context, mode: ComposerMode.income, bucketId: b.id)),
              _Action(icon: Icons.remove_rounded, label: 'Spend', color: colors.expense,
                  onTap: () => openComposer(context, mode: ComposerMode.expense, bucketId: b.id)),
              _Action(icon: Icons.call_split_rounded, label: 'Transfer', color: colors.transfer,
                  onTap: () => openComposer(context, mode: ComposerMode.transfer, bucketId: b.id)),
              _Action(icon: Icons.tune_rounded, label: 'Adjust', color: scheme.onSurfaceVariant,
                  onTap: () => _adjust(context, b, balance)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _FlowTile(label: 'In this month', minor: flow.incomeMinor, color: colors.income, icon: Icons.south_west_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _FlowTile(label: 'Out this month', minor: flow.expenseMinor, color: colors.expense, icon: Icons.north_east_rounded)),
            ],
          ),
          const SizedBox(height: 10),
          const SectionHeader('History'),
          if (txns.isEmpty)
            const EmptyState(emoji: '🧾', title: 'No activity yet', message: 'Money you add, spend or move shows up here.')
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final t in txns)
                      TxnTile(t, forBucketId: b.id, showDate: true, onTap: () => showTxnDetail(context, t)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _adjust(BuildContext context, Bucket b, int balance) async {
    final store = context.read<MoneyStore>();
    final symbol = context.read<SettingsStore>().currency.symbol;
    final ctrl = TextEditingController(text: minorToInput(balance < 0 ? 0 : balance));
    final value = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Set balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Correct the balance of ${b.name}. The difference is recorded as an adjustment, '
                'not as income or spending.'),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,10}(\.\d{0,2})?'))],
              decoration: InputDecoration(prefixText: symbol),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(c, parseMinor(ctrl.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null || !context.mounted) return;
    if (store.adjustBalance(b.id, value) != null) showUndoSnack(context, 'Balance updated');
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.bucket, required this.balance});

  final Bucket bucket;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final fmt = context.watch<SettingsStore>().format;
    final hidden = context.watch<SettingsStore>().hideAmounts;
    final goal = bucket.goalMinor;
    final progress = goal == null || goal == 0 ? null : (balance / goal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bucket.color, Color.lerp(bucket.color, Colors.black, 0.35)!],
        ),
        boxShadow: [BoxShadow(color: bucket.color.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (progress != null)
                  SizedBox.expand(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: progress),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => CircularProgressIndicator(
                        value: v,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        color: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                Hero(
                  tag: 'bucket-${bucket.id}',
                  child: Material(
                    type: MaterialType.transparency,
                    child: Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Text(bucket.emoji, style: const TextStyle(fontSize: 30)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bucket.includeInTotal ? 'Balance' : 'Balance · not in total',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                ),
                AnimatedMoney(balance,
                    color: Colors.white, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                if (goal != null && progress != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    hidden
                        ? '${(progress * 100).round()}% of goal'
                        : progress >= 1
                            ? 'Goal of ${fmt.format(goal, dropZeroDecimals: true)} reached 🎉'
                            : '${(progress * 100).round()}% of ${fmt.format(goal, dropZeroDecimals: true)} · '
                                '${fmt.format(goal - balance, dropZeroDecimals: true)} to go',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlowTile extends StatelessWidget {
  const _FlowTile({required this.label, required this.minor, required this.color, required this.icon});

  final String label;
  final int minor;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: MoneyText(minor, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
