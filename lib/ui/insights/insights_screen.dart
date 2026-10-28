import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/categories.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/money_store.dart';
import '../../state/settings_store.dart';
import '../widgets/common.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int? _touchedSlice;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shift(int months) => setState(() {
        _month = DateTime(_month.year, _month.month + months);
        _touchedSlice = null;
      });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final settings = context.watch<SettingsStore>();
    final colors = MoneyColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final summary = store.monthSummary(_month);
    final byCategory = store.spendByCategory(_month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final daysElapsed = _isCurrentMonth ? DateTime.now().day : daysInMonth;

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          Row(
            children: [
              IconButton.filledTonal(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton.filledTonal(
                onPressed: _isCurrentMonth ? null : () => _shift(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.9,
            children: [
              _StatTile(label: 'Money in', icon: Icons.south_west_rounded, color: colors.income, value: MoneyText(summary.incomeMinor, style: _statStyle)),
              _StatTile(label: 'Spent', icon: Icons.north_east_rounded, color: colors.expense, value: MoneyText(summary.expenseMinor, style: _statStyle)),
              _StatTile(
                label: 'Net saved',
                icon: Icons.savings_rounded,
                color: summary.netMinor >= 0 ? colors.income : colors.expense,
                value: MoneyText(summary.netMinor, signed: true, style: _statStyle),
              ),
              _StatTile(
                label: 'Avg. spend / day',
                icon: Icons.calendar_today_rounded,
                color: scheme.primary,
                value: MoneyText(summary.expenseMinor ~/ math.max(1, daysElapsed), style: _statStyle),
              ),
            ],
          ),
          if (summary.savingsRate != null) ...[
            const SizedBox(height: 10),
            _SavingsRate(rate: summary.savingsRate!),
          ],
          if (settings.monthlyBudgetMinor != null) ...[
            const SizedBox(height: 10),
            _BudgetCard(spent: summary.expenseMinor, budget: settings.monthlyBudgetMinor!),
          ],
          const SizedBox(height: 18),
          const SectionHeader('Where the money went'),
          if (byCategory.isEmpty)
            const Card(child: EmptyState(emoji: '🥧', title: 'No spending this month'))
          else
            _CategoryCard(
              data: byCategory,
              total: summary.expenseMinor,
              touched: _touchedSlice,
              onTouch: (i) => setState(() => _touchedSlice = i),
            ),
          const SizedBox(height: 18),
          const SectionHeader('Daily spending'),
          _DailyChart(store: store, month: _month),
          const SizedBox(height: 18),
          const SectionHeader('Last 6 months'),
          _TrendChart(store: store, endMonth: _month),
          const SizedBox(height: 18),
          const SectionHeader('Balance by bucket'),
          _BucketShare(store: store),
        ],
      ),
    );
  }

  static const _statStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w800);
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.icon, required this.color, required this.value});

  final String label;
  final IconData icon;
  final Color color;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(icon, size: 14, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: value),
          ],
        ),
      ),
    );
  }
}

class _SavingsRate extends StatelessWidget {
  const _SavingsRate({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    final colors = MoneyColors.of(context);
    final good = rate >= 0.2;
    final color = rate < 0 ? colors.expense : (good ? colors.income : const Color(0xFFF59E0B));
    final message = rate < 0
        ? 'You spent more than you earned this month.'
        : good
            ? 'Great — you kept ${(rate * 100).round()}% of what came in.'
            : 'You kept ${(rate * 100).round()}% of what came in. 20%+ is a healthy target.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: rate.clamp(0.0, 1.0),
                    strokeWidth: 5,
                    strokeCap: StrokeCap.round,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.15),
                  ),
                  Text('${(rate * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Savings rate', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(message, style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.spent, required this.budget});

  final int spent;
  final int budget;

  @override
  Widget build(BuildContext context) {
    final colors = MoneyColors.of(context);
    final fmt = context.watch<SettingsStore>().format;
    final ratio = spent / budget;
    final color = ratio > 1 ? colors.expense : (ratio > 0.8 ? const Color(0xFFF59E0B) : colors.income);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Monthly budget', style: TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('${(ratio * 100).round()}% used', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 10,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 8),
            if (!context.watch<SettingsStore>().hideAmounts)
              Text(
                ratio > 1
                    ? 'Over by ${fmt.format(spent - budget)}'
                    : '${fmt.format(budget - spent)} left of ${fmt.format(budget, dropZeroDecimals: true)}',
                style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.data, required this.total, required this.touched, required this.onTouch});

  final List<MapEntry<String, int>> data;
  final int total;
  final int? touched;
  final ValueChanged<int?> onTouch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final i = touched;
    final focus = i != null && i >= 0 && i < data.length ? data[i] : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 62,
                      pieTouchData: PieTouchData(
                        // React to taps only, so scrolling past the chart doesn't change the
                        // selection. The hole and gaps report index -1: treat that as "none".
                        touchCallback: (event, response) {
                          if (event is! FlTapUpEvent) return;
                          final index = response?.touchedSection?.touchedSectionIndex ?? -1;
                          onTouch(index < 0 || index == touched ? null : index);
                        },
                      ),
                      sections: [
                        for (var i = 0; i < data.length; i++)
                          PieChartSectionData(
                            value: data[i].value.toDouble(),
                            color: categoryById(data[i].key).color,
                            radius: i == touched ? 34 : 26,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  // Let taps on the label reach the chart, so tapping the middle clears the focus.
                  IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(focus == null ? 'Total spent' : categoryById(focus.key).name,
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        MoneyText(focus?.value ?? total,
                            dropZeroDecimals: true, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < data.length; i++)
              _CategoryRow(
                category: categoryById(data[i].key),
                minor: data[i].value,
                share: total == 0 ? 0 : data[i].value / total,
                highlighted: i == touched,
                onTap: () => onTouch(i == touched ? null : i),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.minor,
    required this.share,
    required this.highlighted,
    required this.onTap,
  });

  final Category category;
  final int minor;
  final double share;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: highlighted ? category.color.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                      MoneyText(minor, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: share,
                            minHeight: 6,
                            color: category.color,
                            backgroundColor: category.color.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 36,
                        child: Text('${(share * 100).round()}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ),
                    ],
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

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.store, required this.month});

  final MoneyStore store;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final colors = MoneyColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsStore>();
    final days = DateTime(month.year, month.month + 1, 0).day;
    final perDay = List<int>.filled(days, 0);
    for (final t in store.txnsInMonth(month)) {
      if (t.type == TxnType.expense) perDay[t.date.day - 1] += t.amountMinor;
    }
    final maxY = perDay.fold(0, math.max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 18, 16, 8),
        child: SizedBox(
          height: 170,
          child: maxY == 0
              ? Center(child: Text('No spending yet', style: TextStyle(color: scheme.onSurfaceVariant)))
              : BarChart(
                  BarChartData(
                    maxY: maxY * 1.15,
                    alignment: BarChartAlignment.spaceBetween,
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 3,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: scheme.outlineVariant.withValues(alpha: 0.3), strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: !settings.hideAmounts,
                          reservedSize: 46,
                          interval: maxY / 3,
                          getTitlesWidget: (v, meta) => v == meta.max
                              ? const SizedBox.shrink()
                              : Text(settings.format.compact(v.round()),
                                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (v, _) {
                            final d = v.toInt() + 1;
                            if (d != 1 && d % 5 != 0) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('$d', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      enabled: !settings.hideAmounts,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => scheme.inverseSurface,
                        getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                          '${group.x + 1} ${DateFormat('MMM').format(month)}\n${settings.format.format(rod.toY.round())}',
                          TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < days; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: perDay[i].toDouble(),
                            width: 5,
                            color: colors.expense,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ]),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.store, required this.endMonth});

  final MoneyStore store;
  final DateTime endMonth;

  @override
  Widget build(BuildContext context) {
    final colors = MoneyColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsStore>();
    final months = [for (var i = 5; i >= 0; i--) DateTime(endMonth.year, endMonth.month - i)];
    final sums = [for (final m in months) store.monthSummary(m)];
    final maxY = sums.fold(0, (m, s) => math.max(m, math.max(s.incomeMinor, s.expenseMinor)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 18, 16, 10),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: maxY == 0
                  ? Center(child: Text('No data yet', style: TextStyle(color: scheme.onSurfaceVariant)))
                  : BarChart(
                      BarChartData(
                        maxY: maxY * 1.15,
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          horizontalInterval: maxY / 3,
                          getDrawingHorizontalLine: (_) =>
                              FlLine(color: scheme.outlineVariant.withValues(alpha: 0.3), strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: !settings.hideAmounts,
                              reservedSize: 46,
                              interval: maxY / 3,
                              getTitlesWidget: (v, meta) => v == meta.max
                                  ? const SizedBox.shrink()
                                  : Text(settings.format.compact(v.round()),
                                      style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              getTitlesWidget: (v, _) => Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(DateFormat('MMM').format(months[v.toInt()]),
                                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                              ),
                            ),
                          ),
                        ),
                        barTouchData: BarTouchData(
                          enabled: !settings.hideAmounts,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => scheme.inverseSurface,
                            getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
                              '${rodIndex == 0 ? 'In' : 'Out'}: ${settings.format.compact(rod.toY.round())}',
                              TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < months.length; i++)
                            BarChartGroupData(x: i, barsSpace: 4, barRods: [
                              BarChartRodData(
                                toY: sums[i].incomeMinor.toDouble(),
                                width: 10,
                                color: colors.income,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                toY: sums[i].expenseMinor.toDouble(),
                                width: 10,
                                color: colors.expense,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ]),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legend(color: colors.income, label: 'Money in'),
                const SizedBox(width: 18),
                _Legend(color: colors.expense, label: 'Spent'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );
}

class _BucketShare extends StatelessWidget {
  const _BucketShare({required this.store});

  final MoneyStore store;

  @override
  Widget build(BuildContext context) {
    final positive = [
      for (final b in store.buckets)
        if (store.balanceOf(b.id) > 0) (b, store.balanceOf(b.id)),
    ];
    final total = positive.fold(0, (s, e) => s + e.$2);
    if (total == 0) {
      return const Card(child: EmptyState(emoji: '🪣', title: 'Your buckets are empty'));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 16,
                child: Row(
                  children: [
                    for (final (b, v) in positive) Expanded(flex: v, child: Container(color: b.color)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                for (final (b, v) in positive)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: b.color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('${b.emoji} ${b.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text('${(v * 100 / total).round()}%',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
