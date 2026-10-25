import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/money.dart';
import '../../core/split.dart';
import '../../data/models.dart';
import '../../state/settings_store.dart';
import '../widgets/common.dart';

enum SplitMode { percent, amount }

/// Holds the split inputs for one composer mode.
class SplitController extends ChangeNotifier {
  SplitMode _mode = SplitMode.percent;
  final Map<String, TextEditingController> _fields = {};

  SplitMode get mode => _mode;

  TextEditingController field(String id) =>
      _fields.putIfAbsent(id, () => TextEditingController()..addListener(notifyListeners));

  set mode(SplitMode m) {
    if (m == _mode) return;
    _mode = m;
    clear();
  }

  void clear() {
    for (final c in _fields.values) {
      c.text = '';
    }
    notifyListeners();
  }

  void prefill(Map<String, int> bp) {
    _mode = SplitMode.percent;
    for (final c in _fields.values) {
      c.text = '';
    }
    bp.forEach((id, v) => field(id).text = _percentText(v));
    notifyListeners();
  }

  void equal(List<String> ids) {
    _mode = SplitMode.percent;
    final parts = equalBasisPoints(ids.length);
    for (var i = 0; i < ids.length; i++) {
      field(ids[i]).text = _percentText(parts[i]);
    }
    notifyListeners();
  }

  static String _percentText(int bp) {
    final p = basisPointsToPercent(bp);
    return p == p.roundToDouble() ? p.toInt().toString() : p.toStringAsFixed(2);
  }

  /// Basis points per target as typed (percent mode only).
  Map<String, int> basisPoints(Iterable<String> ids) {
    final out = <String, int>{};
    for (final id in ids) {
      final v = double.tryParse(_fields[id]?.text ?? '') ?? 0;
      if (v > 0) out[id] = percentToBasisPoints(v);
    }
    return out;
  }

  /// Minor units per target for [amountMinor].
  Map<String, int> shares(int amountMinor, Iterable<String> ids) {
    if (_mode == SplitMode.percent) return splitByBasisPoints(amountMinor, basisPoints(ids));
    final out = <String, int>{};
    for (final id in ids) {
      final v = parseMinor(_fields[id]?.text ?? '') ?? 0;
      if (v > 0) out[id] = v;
    }
    return out;
  }

  bool overAllocated(int amountMinor, Iterable<String> ids) {
    if (_mode == SplitMode.percent) {
      return basisPoints(ids).values.fold(0, (s, v) => s + v) > fullBasisPoints;
    }
    return shares(amountMinor, ids).values.fold(0, (s, v) => s + v) > amountMinor;
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }
}

/// Split UI: a live allocation bar plus one input per target bucket.
class SplitEditor extends StatelessWidget {
  const SplitEditor({
    super.key,
    required this.controller,
    required this.source,
    required this.targets,
    required this.amountMinor,
    required this.remainderLabel,
  });

  final SplitController controller;
  final Bucket source;
  final List<Bucket> targets;
  final int amountMinor;
  final String remainderLabel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = context.watch<SettingsStore>().format;
    final ids = targets.map((b) => b.id).toList();
    final shares = controller.shares(amountMinor, ids);
    final allocated = shares.values.fold(0, (s, v) => s + v);
    final over = controller.overAllocated(amountMinor, ids);
    final remainder = amountMinor - allocated;
    final percentMode = controller.mode == SplitMode.percent;

    if (targets.isEmpty) {
      return const EmptyState(
        emoji: '🪣',
        title: 'No other buckets yet',
        message: 'Create another bucket to split money into it.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<SplitMode>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: SplitMode.percent, label: Text('%')),
                  ButtonSegment(value: SplitMode.amount, label: Text('Amount')),
                ],
                selected: {controller.mode},
                onSelectionChanged: (s) => controller.mode = s.first,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Split equally',
              onPressed: () => controller.equal(ids),
              icon: const Icon(Icons.balance_rounded),
            ),
            IconButton(
              tooltip: 'Clear split',
              onPressed: controller.clear,
              icon: const Icon(Icons.backspace_outlined),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _AllocationBar(
          source: source,
          targets: targets,
          shares: shares,
          amountMinor: amountMinor,
          over: over,
        ),
        const SizedBox(height: 8),
        Text(
          over
              ? 'Split is more than ${percentMode ? '100%' : 'the amount'}'
              : '$remainderLabel ${source.name}: ${fmt.format(remainder < 0 ? 0 : remainder)}',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: over ? scheme.error : scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final b in targets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                BucketAvatar(b, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        percentMode
                            ? (shares[b.id] ?? 0) > 0
                                ? '+ ${fmt.format(shares[b.id]!)}'
                                : '—'
                            : amountMinor > 0 && (shares[b.id] ?? 0) > 0
                                ? '${(shares[b.id]! * 100 / amountMinor).toStringAsFixed(1)}%'
                                : '—',
                        style: TextStyle(fontSize: 12, color: b.color, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: controller.field(b.id),
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d{0,9}(\.\d{0,2})?')),
                    ],
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '0',
                      // Icons (unlike prefix/suffix text) stay visible while the field is empty.
                      prefixIcon: percentMode ? null : _Affix(fmt.currency.symbol.trim()),
                      prefixIconConstraints: const BoxConstraints(minWidth: 28),
                      suffixIcon: percentMode ? const _Affix('%') : null,
                      suffixIconConstraints: const BoxConstraints(minWidth: 28),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Affix extends StatelessWidget {
  const _Affix(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        widthFactor: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(text,
              style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
}

class _AllocationBar extends StatelessWidget {
  const _AllocationBar({
    required this.source,
    required this.targets,
    required this.shares,
    required this.amountMinor,
    required this.over,
  });

  final Bucket source;
  final List<Bucket> targets;
  final Map<String, int> shares;
  final int amountMinor;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = amountMinor <= 0 ? 1 : amountMinor;
    final allocated = shares.values.fold(0, (s, v) => s + v);
    final remainder = (total - allocated).clamp(0, total);

    final parts = <(Color, int)>[
      for (final b in targets)
        if ((shares[b.id] ?? 0) > 0) (b.color, shares[b.id]!),
      if (remainder > 0 || allocated == 0) (source.color.withValues(alpha: 0.25), remainder == 0 ? 1 : remainder),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          border: over ? Border.all(color: scheme.error, width: 2) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            for (final (color, value) in parts)
              Expanded(
                flex: value.clamp(1, 1 << 30),
                child: AnimatedContainer(duration: const Duration(milliseconds: 250), color: color),
              ),
          ],
        ),
      ),
    );
  }
}
