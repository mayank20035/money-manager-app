import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/categories.dart';
import '../../core/period.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/money_store.dart';
import '../../state/settings_store.dart';
import '../bucket/bucket_detail_page.dart';
import '../widgets/common.dart';

/// How money moved through each bucket during [period]: highlights, a
/// diverging in/out bar per bucket, and an expandable breakdown.
class BucketFlowSection extends StatelessWidget {
  const BucketFlowSection({super.key, required this.period});

  final Period period;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final scheme = Theme.of(context).colorScheme;
    final flows = store.bucketFlows(period);
    final active = flows.where((f) => !f.isQuiet).toList()
      ..sort((a, b) => (b.inflowMinor + b.outflowMinor).compareTo(a.inflowMinor + a.outflowMinor));
    final quiet = [
      for (final f in flows)
        if (f.isQuiet) store.bucket(f.bucketId)!,
    ];

    if (active.isEmpty) {
      return Card(
        child: EmptyState(
          emoji: '🪣',
          title: 'No bucket activity this ${period.noun}',
          message: 'Add, spend or move money and you\'ll see how each bucket fills and drains.',
        ),
      );
    }

    // Every bar is scaled against the busiest side of the busiest bucket.
    final maxSide = active.fold(1, (m, f) => math.max(m, math.max(f.inflowMinor, f.outflowMinor)));

    return Column(
      children: [
        _Highlights(flows: active),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              children: [
                const _Legend(),
                const SizedBox(height: 4),
                for (var i = 0; i < active.length; i++) ...[
                  if (i > 0) const Divider(),
                  _FlowRow(
                    key: ValueKey(active[i].bucketId),
                    flow: active[i],
                    bucket: store.bucket(active[i].bucketId)!,
                    maxSide: maxSide,
                    period: period,
                  ),
                ],
                if (quiet.isNotEmpty) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 2),
                    child: Row(
                      children: [
                        Text(quiet.map((b) => b.emoji).join(' '), style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            quiet.length == 1
                                ? '${quiet.single.name} had no activity this ${period.noun}'
                                : '${quiet.length} buckets had no activity this ${period.noun}',
                            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ highlights

class _Highlight {
  const _Highlight(this.badge, this.label, this.title, this.minor, this.color, {this.signed = false});

  final String badge;
  final String label;
  final String title;
  final int minor;
  final Color color;
  final bool signed;
}

class _Highlights extends StatelessWidget {
  const _Highlights({required this.flows});

  final List<BucketFlow> flows;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final colors = MoneyColors.of(context);
    Bucket b(String id) => store.bucket(id)!;

    final items = <_Highlight>[];
    final spender = flows.reduce((x, y) => y.spentMinor > x.spentMinor ? y : x);
    if (spender.spentMinor > 0) {
      final top = spender.spendByCategory.entries.reduce((x, y) => y.value > x.value ? y : x);
      final cat = categoryById(top.key);
      items.add(_Highlight('🔥', 'Spent the most', '${b(spender.bucketId).emoji} ${b(spender.bucketId).name}',
          spender.spentMinor, colors.expense));
      items.add(_Highlight(cat.emoji, 'Biggest expense', '${cat.name} · ${b(spender.bucketId).name}', top.value,
          cat.color));
    }
    final grower = flows.reduce((x, y) => y.netMinor > x.netMinor ? y : x);
    if (grower.netMinor > 0) {
      items.add(_Highlight('🌱', 'Grew the most', '${b(grower.bucketId).emoji} ${b(grower.bucketId).name}',
          grower.netMinor, colors.income,
          signed: true));
    }
    MapEntry<(String, String), int>? move;
    for (final f in flows) {
      for (final e in f.movedTo.entries) {
        if (move == null || e.value > move.value) move = MapEntry((f.bucketId, e.key), e.value);
      }
    }
    if (move != null) {
      final (from, to) = move.key;
      items.add(_Highlight('🔀', 'Biggest move', '${b(from).emoji} → ${b(to).emoji} ${b(to).name}', move.value,
          colors.transfer));
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _HighlightCard(item: items[i]),
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.item});

  final _Highlight item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 176,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: item.color.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [item.color.withValues(alpha: 0.14), item.color.withValues(alpha: 0.02)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(item.badge, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: item.color)),
              ),
            ],
          ),
          Text(item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(item.minor,
                signed: item.signed,
                dropZeroDecimals: true,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final colors = MoneyColors.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget dot(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11.5, color: muted, fontWeight: FontWeight.w600)),
          ],
        );
    // The keys wrap onto a second line on narrow screens or with large text.
    return Row(
      children: [
        Icon(Icons.west_rounded, size: 14, color: muted),
        Text(' out', style: TextStyle(fontSize: 11.5, color: muted, fontWeight: FontWeight.w600)),
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              dot(colors.expense, 'Spent'),
              dot(colors.transfer, 'Moved'),
              dot(colors.income, 'Added'),
            ],
          ),
        ),
        Text('in ', style: TextStyle(fontSize: 11.5, color: muted, fontWeight: FontWeight.w600)),
        Icon(Icons.east_rounded, size: 14, color: muted),
      ],
    );
  }
}

// ------------------------------------------------------------------- bucket row

class _FlowRow extends StatefulWidget {
  const _FlowRow({
    super.key,
    required this.flow,
    required this.bucket,
    required this.maxSide,
    required this.period,
  });

  final BucketFlow flow;
  final Bucket bucket;
  final int maxSide;
  final Period period;

  @override
  State<_FlowRow> createState() => _FlowRowState();
}

class _FlowRowState extends State<_FlowRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.flow;
    final b = widget.bucket;
    final colors = MoneyColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final small = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600);

    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            tapFeedback(context);
            setState(() => _open = !_open);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            child: Column(
              children: [
                Row(
                  children: [
                    BucketAvatar(b, size: 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          // Balance journey: start of period → end of period.
                          Row(
                            children: [
                              Flexible(child: MoneyText(f.openingMinor, dropZeroDecimals: true, style: small)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: Icon(Icons.arrow_right_alt_rounded, size: 16, color: scheme.onSurfaceVariant),
                              ),
                              Flexible(
                                child: MoneyText(f.closingMinor,
                                    dropZeroDecimals: true,
                                    style: small.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MoneyText(
                          f.netMinor,
                          signed: true,
                          dropZeroDecimals: true,
                          color: f.netMinor >= 0 ? colors.income : colors.expense,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        Text('net', style: small.copyWith(fontSize: 11)),
                      ],
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(Icons.expand_more_rounded, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _DivergingBar(flow: f, maxSide: widget.maxSide),
                const SizedBox(height: 5),
                Row(
                  children: [
                    MoneyText(-f.outflowMinor,
                        dropZeroDecimals: true,
                        color: f.outflowMinor > 0 ? colors.expense : scheme.onSurfaceVariant,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(' out', style: small.copyWith(fontSize: 11)),
                    // Adjustments move the balance without being in or out, so name them
                    // here or "₹0 → ₹50,000" with a net of ₹0 would look wrong.
                    Expanded(
                      child: f.adjustedMinor == 0
                          ? const SizedBox.shrink()
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('⚖️ ', style: TextStyle(fontSize: 11)),
                                Flexible(
                                  child: MoneyText(f.adjustedMinor,
                                      signed: true, dropZeroDecimals: true, style: small.copyWith(fontSize: 11)),
                                ),
                                Text(' adjusted', style: small.copyWith(fontSize: 11)),
                              ],
                            ),
                    ),
                    MoneyText(f.inflowMinor,
                        signed: true,
                        dropZeroDecimals: true,
                        color: f.inflowMinor > 0 ? colors.income : scheme.onSurfaceVariant,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(' in', style: small.copyWith(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open ? _FlowDetails(flow: f, bucket: b, period: widget.period) : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Out grows left from the centre line, in grows right. Spent and added sit
/// next to the centre; money moved between buckets sits on the outside.
class _DivergingBar extends StatelessWidget {
  const _DivergingBar({required this.flow, required this.maxSide});

  final BucketFlow flow;
  final int maxSide;

  @override
  Widget build(BuildContext context) {
    final colors = MoneyColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final track = scheme.surfaceContainerHighest.withValues(alpha: 0.6);

    Widget half({required bool left, required List<(int, Color)> parts}) {
      final total = parts.fold(0, (s, p) => s + p.$1);
      final radius = left
          ? const BorderRadius.horizontal(left: Radius.circular(7))
          : const BorderRadius.horizontal(right: Radius.circular(7));
      return Expanded(
        child: ClipRRect(
          borderRadius: radius,
          child: Container(
            height: 14,
            color: track,
            alignment: left ? Alignment.centerRight : Alignment.centerLeft,
            child: total == 0
                ? null
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: total / maxSide),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => FractionallySizedBox(
                      widthFactor: v.clamp(0.0, 1.0),
                      child: ClipRRect(
                        borderRadius: radius,
                        child: Row(
                          children: [
                            for (final (value, color) in parts)
                              if (value > 0) Expanded(flex: value, child: Container(color: color)),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      );
    }

    return Row(
      children: [
        half(left: true, parts: [
          (flow.movedOutMinor, colors.transfer.withValues(alpha: 0.75)),
          (flow.spentMinor, colors.expense),
        ]),
        Container(
          width: 2,
          height: 22,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(color: scheme.onSurfaceVariant.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(1)),
        ),
        half(left: false, parts: [
          (flow.addedMinor, colors.income),
          (flow.movedInMinor, colors.transfer),
        ]),
      ],
    );
  }
}

// ---------------------------------------------------------------- expanded part

class _FlowDetails extends StatelessWidget {
  const _FlowDetails({required this.flow, required this.bucket, required this.period});

  final BucketFlow flow;
  final Bucket bucket;
  final Period period;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final colors = MoneyColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final f = flow;

    List<_Line> sorted(Map<String, int> map, _Line Function(String id, int v) make) =>
        (map.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) => make(e.key, e.value)).toList();

    final cameIn = [
      ...sorted(f.incomeBySource, (id, v) {
        final c = categoryById(id);
        return _Line(c.emoji, c.name, v, colors.income);
      }),
      ...sorted(f.movedFrom, (id, v) {
        final from = store.bucket(id);
        return _Line(from?.emoji ?? '🪣', 'From ${from?.name ?? 'a deleted bucket'}', v, colors.transfer);
      }),
    ];
    final wentOut = [
      ...sorted(f.spendByCategory, (id, v) {
        final c = categoryById(id);
        return _Line(c.emoji, c.name, v, c.color);
      }),
      ...sorted(f.movedTo, (id, v) {
        final to = store.bucket(id);
        return _Line(to?.emoji ?? '🪣', 'To ${to?.name ?? 'a deleted bucket'}', v, colors.transfer);
      }),
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: bucket.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: bucket.color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Sparkline(bucket: bucket, period: period, series: store.balanceSeries(bucket.id, period)),
          const SizedBox(height: 12),
          _LineGroup(title: 'Came in', total: f.inflowMinor, lines: cameIn, empty: 'Nothing came in', signed: true),
          const SizedBox(height: 12),
          _LineGroup(title: 'Went out', total: f.outflowMinor, lines: wentOut, empty: 'Nothing went out'),
          if (f.adjustedMinor != 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('⚖️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(child: Text('Balance adjustments', style: TextStyle(color: scheme.onSurfaceVariant))),
                MoneyText(f.adjustedMinor, signed: true, dropZeroDecimals: true,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => BucketDetailPage(bucketId: bucket.id))),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text('Open ${bucket.name}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line {
  const _Line(this.emoji, this.label, this.minor, this.color);

  final String emoji;
  final String label;
  final int minor;
  final Color color;
}

class _LineGroup extends StatelessWidget {
  const _LineGroup({
    required this.title,
    required this.total,
    required this.lines,
    required this.empty,
    this.signed = false,
  });

  final String title;
  final int total;
  final List<_Line> lines;
  final String empty;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title.toUpperCase(),
                style: TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant)),
            const Spacer(),
            MoneyText(signed ? total : -total,
                signed: signed,
                dropZeroDecimals: true,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 6),
        if (lines.isEmpty)
          Text(empty, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant))
        else
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 24, child: Text(l.emoji, style: const TextStyle(fontSize: 16))),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(l.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                            MoneyText(l.minor,
                                dropZeroDecimals: true, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: total == 0 ? 0 : l.minor / total,
                            minHeight: 4,
                            color: l.color,
                            backgroundColor: l.color.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// The bucket's balance across the period, in the bucket's colour.
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.bucket, required this.period, required this.series});

  final Bucket bucket;
  final Period period;
  final List<int?> series;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final scheme = Theme.of(context).colorScheme;
    final spots = [
      for (var i = 0; i < series.length; i++)
        if (series[i] != null) FlSpot(i.toDouble(), series[i]!.toDouble()),
    ];
    if (spots.length < 2) return const SizedBox.shrink();

    final lo = spots.map((s) => s.y).reduce(math.min);
    final hi = spots.map((s) => s.y).reduce(math.max);
    final pad = hi == lo ? math.max(hi.abs() * 0.1, 100) : (hi - lo) * 0.15;
    final slots = period.slots;
    final fmt = period.kind == PeriodKind.year ? DateFormat('MMM') : DateFormat('d MMM');
    final muted = TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BALANCE THIS ${period.noun.toUpperCase()}',
            style: TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: LineChart(
            LineChartData(
              minX: 0,
              // The current period ends at today, so the right edge matches its "Today" label.
              maxX: period.isCurrent ? spots.last.x : (slots.length - 1).toDouble(),
              minY: lo - pad,
              maxY: hi + pad,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              lineTouchData: LineTouchData(
                enabled: !settings.hideAmounts,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => scheme.inverseSurface,
                  getTooltipItems: (touched) => [
                    for (final t in touched)
                      LineTooltipItem(
                        '${fmt.format(slots[t.x.toInt()])}\n${settings.format.format(t.y.round())}',
                        TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: bucket.color,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    checkToShowDot: (spot, _) => spot == spots.last,
                    getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                      radius: 4.5,
                      color: bucket.color,
                      strokeWidth: 2.5,
                      strokeColor: Theme.of(context).cardTheme.color ?? Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [bucket.color.withValues(alpha: 0.28), bucket.color.withValues(alpha: 0.0)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(fmt.format(slots.first), style: muted),
            const Spacer(),
            Text(period.isCurrent ? 'Today' : fmt.format(slots.last), style: muted),
          ],
        ),
      ],
    );
  }
}
