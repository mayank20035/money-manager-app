import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/categories.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../state/money_store.dart';
import '../../state/settings_store.dart';
import '../widgets/common.dart';

/// Create (bucket == null) or edit a bucket. Resolves to true when the bucket was deleted.
Future<bool> showBucketEditor(BuildContext context, {Bucket? bucket}) async {
  final deleted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _BucketEditor(bucket: bucket),
  );
  return deleted ?? false;
}

class _BucketEditor extends StatefulWidget {
  const _BucketEditor({this.bucket});

  final Bucket? bucket;

  @override
  State<_BucketEditor> createState() => _BucketEditorState();
}

class _BucketEditorState extends State<_BucketEditor> {
  late final _name = TextEditingController(text: widget.bucket?.name ?? '');
  late final _goal = TextEditingController(
      text: widget.bucket?.goalMinor == null ? '' : minorToInput(widget.bucket!.goalMinor!));
  final _opening = TextEditingController();
  late String _emoji = widget.bucket?.emoji ?? bucketEmojis[3];
  late int _color;
  late bool _include = widget.bucket?.includeInTotal ?? true;

  bool get _isNew => widget.bucket == null;

  @override
  void initState() {
    super.initState();
    // New buckets cycle through the palette so neighbours look different.
    _color = widget.bucket?.colorValue ??
        bucketColors[context.read<MoneyStore>().buckets.length % bucketColors.length].toARGB32();
  }

  @override
  void dispose() {
    _name.dispose();
    _goal.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _save() {
    final store = context.read<MoneyStore>();
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final goal = parseMinor(_goal.text);
    if (_isNew) {
      store.addBucket(
        name: name,
        emoji: _emoji,
        colorValue: _color,
        includeInTotal: _include,
        goalMinor: (goal ?? 0) > 0 ? goal : null,
        openingMinor: parseMinor(_opening.text) ?? 0,
      );
      showUndoSnack(context, 'Created $name');
    } else {
      store.updateBucket(widget.bucket!.copyWith(
        name: name,
        emoji: _emoji,
        colorValue: _color,
        includeInTotal: _include,
        goalMinor: () => (goal ?? 0) > 0 ? goal : null,
      ));
    }
    Navigator.pop(context, false);
  }

  Future<void> _delete() async {
    final store = context.read<MoneyStore>();
    final fmt = context.read<SettingsStore>().format;
    final b = widget.bucket!;
    final ok = await confirmDialog(
      context,
      title: 'Delete ${b.name}?',
      message: 'Its balance of ${fmt.format(store.balanceOf(b.id))} and its history will be removed. '
          'Other buckets keep their balances.',
    );
    if (!ok || !mounted) return;
    store.deleteBucket(b.id);
    showUndoSnack(context, 'Deleted ${b.name}');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final symbol = context.watch<SettingsStore>().currency.symbol;
    final preview = Bucket(id: '-', name: _name.text, emoji: _emoji, colorValue: _color);
    final amountFormatter = FilteringTextInputFormatter.allow(RegExp(r'^\d{0,10}(\.\d{0,2})?'));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BucketAvatar(preview, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _isNew ? 'New bucket' : 'Edit bucket',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              autofocus: _isNew,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Emergency fund'),
            ),
            const SizedBox(height: 16),
            _label(context, 'Icon'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in bucketEmojis)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _emoji = e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: e == _emoji ? Color(_color).withValues(alpha: 0.2) : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: e == _emoji ? Border.all(color: Color(_color), width: 2) : null,
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _label(context, 'Colour'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in bucketColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = c.toARGB32()),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.toARGB32() == _color ? scheme.onSurface : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: c.toARGB32() == _color ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _goal,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [amountFormatter],
              decoration: InputDecoration(
                labelText: 'Savings goal (optional)',
                prefixText: symbol,
                prefixIcon: const Icon(Icons.flag_rounded),
              ),
            ),
            if (_isNew) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _opening,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [amountFormatter],
                decoration: InputDecoration(
                  labelText: 'Current balance (optional)',
                  prefixText: symbol,
                  prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                ),
              ),
            ],
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Include in total balance'),
              value: _include,
              onChanged: (v) => setState(() => _include = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _name.text.trim().isEmpty ? null : _save,
              child: Text(_isNew ? 'Create bucket' : 'Save changes'),
            ),
            if (!_isNew) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: scheme.error, minimumSize: const Size.fromHeight(48)),
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete bucket'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text,
            style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}
