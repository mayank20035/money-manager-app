import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/money_store.dart';
import '../../state/settings_store.dart';
import '../bucket/bucket_detail_page.dart';
import '../bucket/bucket_editor_sheet.dart';
import '../composer/composer_page.dart';
import '../history/txn_detail_sheet.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onSeeAllActivity});

  final VoidCallback onSeeAllActivity;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final settings = context.watch<SettingsStore>();
    final scheme = Theme.of(context).colorScheme;
    final recent = store.txns.take(5).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting(), style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                          Text('Your money',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.6)),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: settings.hideAmounts ? 'Show amounts' : 'Hide amounts',
                      onPressed: () => settings.hideAmounts = !settings.hideAmounts,
                      icon: Icon(settings.hideAmounts ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: _HeroCard(store: store)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              sliver: SliverToBoxAdapter(child: _QuickActions()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 8, 0),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  'Buckets',
                  trailing: TextButton.icon(
                    onPressed: () => showBucketEditor(context),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('New'),
                  ),
                ),
              ),
            ),
            if (store.buckets.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _AddBucketCard(onTap: () => showBucketEditor(context)),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverReorderableList(
                  itemCount: store.buckets.length,
                  onReorder: (from, to) => store.reorderBuckets(from, to > from ? to - 1 : to),
                  proxyDecorator: (child, _, animation) => AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) => Transform.scale(
                      scale: 1 + 0.03 * Curves.easeOut.transform(animation.value),
                      child: Material(type: MaterialType.transparency, child: child),
                    ),
                    child: child,
                  ),
                  itemBuilder: (context, i) {
                    final b = store.buckets[i];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(b.id),
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BucketCard(bucket: b, balance: store.balanceOf(b.id)),
                      ),
                    );
                  },
                ),
              ),
            if (store.buckets.length > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Long-press a bucket to reorder',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 8, 0),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  'Recent activity',
                  trailing: recent.isEmpty ? null : TextButton(onPressed: onSeeAllActivity, child: const Text('See all')),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
              sliver: SliverToBoxAdapter(
                child: recent.isEmpty
                    ? const Card(
                        child: EmptyState(
                          emoji: '✨',
                          title: 'A fresh start',
                          message: 'Tap + on a bucket or the Add button to record your first entry.',
                        ),
                      )
                    : Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              for (final t in recent)
                                TxnTile(t, showDate: true, onTap: () => showTxnDetail(context, t)),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.store});

  final MoneyStore store;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final month = store.monthSummary(DateTime.now());
    final budget = settings.monthlyBudgetMinor;
    final accent = settings.accent;
    final deep = Color.lerp(accent, Colors.black, 0.45)!;
    const onHero = Colors.white;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(accent, Colors.white, 0.08)!, deep],
        ),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 12))],
      ),
      child: Stack(
        children: [
          // Decorative rings.
          Positioned(right: -40, top: -50, child: _Ring(size: 180, color: onHero.withValues(alpha: 0.08))),
          Positioned(right: 40, bottom: -70, child: _Ring(size: 140, color: onHero.withValues(alpha: 0.06))),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 14, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Total balance',
                        style: TextStyle(color: onHero.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                    const Spacer(),
                    _FilterButton(excluded: store.excludedCount),
                  ],
                ),
                AnimatedMoney(
                  store.totalBalance,
                  color: onHero,
                  style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1.2),
                ),
                if (store.excludedCount > 0)
                  Text(
                    '${store.excludedCount} bucket${store.excludedCount == 1 ? '' : 's'} not counted',
                    style: TextStyle(color: onHero.withValues(alpha: 0.7), fontSize: 12),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _HeroStat(icon: Icons.south_west_rounded, label: 'In this month', minor: month.incomeMinor),
                    ),
                    Expanded(
                      child: _HeroStat(icon: Icons.north_east_rounded, label: 'Spent this month', minor: month.expenseMinor),
                    ),
                  ],
                ),
                if (budget != null) ...[
                  const SizedBox(height: 14),
                  _BudgetBar(spent: month.expenseMinor, budget: budget),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 26)),
      );
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.icon, required this.label, required this.minor});

  final IconData icon;
  final String label;
  final int minor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11.5)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: MoneyText(minor,
                    dropZeroDecimals: true,
                    color: Colors.white,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BudgetBar extends StatelessWidget {
  const _BudgetBar({required this.spent, required this.budget});

  final int spent;
  final int budget;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final ratio = spent / budget;
    final over = ratio > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Monthly budget', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
            const Spacer(),
            Text(
              settings.hideAmounts
                  ? '${(ratio * 100).round()}%'
                  : over
                      ? 'Over by ${settings.format.format(spent - budget, dropZeroDecimals: true)}'
                      : '${settings.format.format(budget - spent, dropZeroDecimals: true)} left',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: ratio.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              color: over ? const Color(0xFFFCA5A5) : Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.excluded});

  final int excluded;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Choose buckets in total',
      onPressed: () => _showIncludeSheet(context),
      style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.16)),
      icon: Badge(
        isLabelVisible: excluded > 0,
        label: Text('$excluded'),
        child: const Icon(Icons.filter_list_rounded, color: Colors.white, size: 20),
      ),
    );
  }

  void _showIncludeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => Consumer<MoneyStore>(
        builder: (c, store, _) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.7),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                const SectionHeader('Include in total'),
                Text('Turn off buckets you don\'t want counted, like long-term investments.',
                    style: TextStyle(color: Theme.of(c).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                for (final b in store.buckets)
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    secondary: BucketAvatar(b, size: 40),
                    title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: MoneyText(store.balanceOf(b.id)),
                    value: b.includeInTotal,
                    onChanged: (_) => store.toggleInclude(b.id),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = MoneyColors.of(context);
    Widget action(IconData icon, String label, Color color, ComposerMode mode) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => openComposer(context, mode: mode),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  child: Column(
                    children: [
                      Icon(icon, color: color, size: 24),
                      const SizedBox(height: 4),
                      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
    return Row(
      children: [
        action(Icons.add_circle_rounded, 'Add', colors.income, ComposerMode.income),
        action(Icons.remove_circle_rounded, 'Spend', colors.expense, ComposerMode.expense),
        action(Icons.swap_horiz_rounded, 'Transfer', colors.transfer, ComposerMode.transfer),
      ],
    );
  }
}

class _BucketCard extends StatelessWidget {
  const _BucketCard({required this.bucket, required this.balance});

  final Bucket bucket;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = MoneyColors.of(context);
    final settings = context.watch<SettingsStore>();
    final goal = bucket.goalMinor;
    final progress = goal == null || goal == 0 ? null : (balance / goal).clamp(0.0, 1.0);
    final dim = !bucket.includeInTotal;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BucketDetailPage(bucketId: bucket.id))),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: bucket.color, width: 5)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Column(
            children: [
              Row(
                children: [
                  Opacity(opacity: dim ? 0.55 : 1, child: BucketAvatar(bucket, size: 48, heroTag: 'bucket-${bucket.id}')),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(bucket.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                            ),
                            if (dim) ...[
                              const SizedBox(width: 6),
                              Tooltip(
                                message: 'Not counted in total',
                                child: Icon(Icons.filter_alt_off_rounded, size: 14, color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        AnimatedMoney(
                          balance,
                          color: balance < 0 ? colors.expense : (dim ? scheme.onSurfaceVariant : scheme.onSurface),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                      ],
                    ),
                  ),
                  _RoundButton(
                    icon: Icons.remove_rounded,
                    color: colors.expense,
                    tooltip: 'Spend from ${bucket.name}',
                    onTap: () => openComposer(context, mode: ComposerMode.expense, bucketId: bucket.id),
                  ),
                  const SizedBox(width: 8),
                  _RoundButton(
                    icon: Icons.add_rounded,
                    color: scheme.primary,
                    filled: true,
                    tooltip: 'Add to ${bucket.name}',
                    onTap: () => openComposer(context, mode: ComposerMode.income, bucketId: bucket.id),
                  ),
                ],
              ),
              if (progress != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: progress),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, _) => LinearProgressIndicator(
                            value: v,
                            minHeight: 7,
                            color: bucket.color,
                            backgroundColor: bucket.color.withValues(alpha: 0.14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      settings.hideAmounts
                          ? '${(progress * 100).round()}%'
                          : '${(progress * 100).round()}% of ${settings.format.format(goal!, dropZeroDecimals: true)}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
    this.filled = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? color : color.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: filled ? Theme.of(context).colorScheme.onPrimary : color),
          ),
        ),
      ),
    );
  }
}

class _AddBucketCard extends StatelessWidget {
  const _AddBucketCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.4), width: 1.5),
          color: scheme.primary.withValues(alpha: 0.05),
        ),
        child: Column(
          children: [
            Icon(Icons.add_circle_outline_rounded, color: scheme.primary, size: 32),
            const SizedBox(height: 8),
            Text('Create your first bucket', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Buckets are pots of money — spending cash, savings, investments, a trip fund…',
                textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}
