import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/categories.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/money_store.dart';
import '../../state/settings_store.dart';

const tabular = [FontFeature.tabularFigures()];

void tapFeedback(BuildContext context) {
  if (context.read<SettingsStore>().haptics) HapticFeedback.selectionClick();
}

/// Shows [message] with an Undo action wired to the store.
void showUndoSnack(BuildContext context, String message) {
  final store = context.read<MoneyStore>();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 4),
      // Action snack bars persist by default; Undo should fade away on its own.
      persist: false,
      action: SnackBarAction(label: 'Undo', onPressed: store.undo),
    ));
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String friendlyDay(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (d.year == now.year) return DateFormat('EEE, d MMM').format(d);
  return DateFormat('d MMM yyyy').format(d);
}

/// Privacy-aware amount text.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.minor, {
    super.key,
    this.style,
    this.signed = false,
    this.dropZeroDecimals = false,
    this.color,
  });

  final int minor;
  final TextStyle? style;
  final bool signed;
  final bool dropZeroDecimals;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final text = settings.hideAmounts
        ? settings.format.masked()
        : settings.format.format(minor, signed: signed, dropZeroDecimals: dropZeroDecimals);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: (style ?? const TextStyle()).copyWith(color: color, fontFeatures: tabular),
    );
  }
}

/// Counts up/down to the new value whenever [minor] changes.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney(this.minor, {super.key, this.style, this.color});

  final int minor;
  final TextStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: minor.toDouble()),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: MoneyText(v.round(), style: style, color: color),
      ),
    );
  }
}

class BucketAvatar extends StatelessWidget {
  const BucketAvatar(this.bucket, {super.key, this.size = 44, this.heroTag});

  final Bucket bucket;
  final double size;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bucket.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(bucket.emoji, style: TextStyle(fontSize: size * 0.48)),
    );
    if (heroTag == null) return avatar;
    return Hero(tag: heroTag!, child: Material(type: MaterialType.transparency, child: avatar));
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.emoji, required this.title, this.message});

  final String emoji;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Visual identity of a transaction: emoji, title, colour.
class TxnLook {
  TxnLook(this.txn, MoneyStore store, MoneyColors colors)
      : emoji = switch (txn.type) {
          TxnType.transfer => '🔀',
          TxnType.adjustment => '⚖️',
          _ => categoryById(txn.categoryId).emoji,
        },
        tint = switch (txn.type) {
          TxnType.income => colors.income,
          TxnType.expense => categoryById(txn.categoryId).color,
          TxnType.transfer => colors.transfer,
          TxnType.adjustment => const Color(0xFF64748B),
        },
        title = txn.note.isNotEmpty
            ? txn.note
            : switch (txn.type) {
                TxnType.transfer => 'Transfer',
                TxnType.adjustment => 'Balance adjustment',
                _ => categoryById(txn.categoryId).name,
              },
        subtitle = _subtitle(txn, store);

  final Txn txn;
  final String emoji;
  final Color tint;
  final String title;
  final String subtitle;

  static String _subtitle(Txn t, MoneyStore store) {
    String name(String id) => store.bucket(id)?.name ?? 'Deleted bucket';
    switch (t.type) {
      case TxnType.expense:
        final cat = t.note.isNotEmpty ? '${categoryById(t.categoryId).name} · ' : '';
        return '$cat${name(t.primaryBucketId!)}';
      case TxnType.income:
        final others = t.legs.skip(1).where((l) => l.amountMinor > 0).toList();
        final cat = t.note.isNotEmpty ? '${categoryById(t.categoryId).name} · ' : '';
        final split = switch (others.length) {
          0 => '',
          1 => ' · split with ${name(others.first.bucketId)}',
          _ => ' · split ${others.length + 1} ways',
        };
        return '$cat${name(t.primaryBucketId!)}$split';
      case TxnType.transfer:
        final targets = t.legs.where((l) => l.amountMinor > 0).map((l) => name(l.bucketId));
        return '${name(t.primaryBucketId!)} → ${targets.join(', ')}';
      case TxnType.adjustment:
        return name(t.primaryBucketId!);
    }
  }
}

class TxnTile extends StatelessWidget {
  const TxnTile(this.txn, {super.key, this.forBucketId, this.onTap, this.showDate = false});

  final Txn txn;

  /// When set, shows this bucket's side of the transaction.
  final String? forBucketId;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final colors = MoneyColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final look = TxnLook(txn, store, colors);

    final int amount;
    final Color amountColor;
    if (forBucketId != null) {
      amount = txn.deltaFor(forBucketId!);
      amountColor = amount >= 0 ? colors.income : colors.expense;
    } else {
      switch (txn.type) {
        case TxnType.income:
          amount = txn.amountMinor;
          amountColor = colors.income;
        case TxnType.expense:
          amount = -txn.amountMinor;
          amountColor = colors.expense;
        case TxnType.transfer:
          amount = txn.amountMinor;
          amountColor = colors.transfer;
        case TxnType.adjustment:
          amount = txn.amountMinor;
          amountColor = scheme.onSurfaceVariant;
      }
    }
    final signed = txn.type != TxnType.transfer || forBucketId != null;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: look.tint.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(look.emoji, style: const TextStyle(fontSize: 20)),
      ),
      title: Text(look.title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        showDate ? '${friendlyDay(txn.date)} · ${look.subtitle}' : look.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
      ),
      trailing: MoneyText(
        amount,
        signed: signed,
        color: amountColor,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Delete',
  bool destructive = true,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                  minimumSize: const Size(0, 44),
                )
              : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}
