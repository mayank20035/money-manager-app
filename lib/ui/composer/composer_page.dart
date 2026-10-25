import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/calculator.dart';
import '../../core/categories.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/money_store.dart';
import '../../state/settings_store.dart';
import '../widgets/common.dart';
import 'keypad.dart';
import 'split_editor.dart';

enum ComposerMode { expense, income, transfer }

Future<void> openComposer(BuildContext context, {ComposerMode mode = ComposerMode.expense, String? bucketId}) {
  // A lingering snack bar would cover the Save button.
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  return Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ComposerPage(initialMode: mode, bucketId: bucketId),
  ));
}

class _ItemDraft {
  _ItemDraft({this.categoryId = 'food'});

  String expr = '';
  String categoryId;
  final note = TextEditingController();
}

/// One screen for spending, adding money and transferring between buckets.
class ComposerPage extends StatefulWidget {
  const ComposerPage({super.key, required this.initialMode, this.bucketId});

  final ComposerMode initialMode;
  final String? bucketId;

  @override
  State<ComposerPage> createState() => _ComposerPageState();
}

class _ComposerPageState extends State<ComposerPage> {
  late ComposerMode _mode = widget.initialMode;
  String? _bucketId;
  DateTime _date = DateTime.now();

  // Expense
  final _items = [_ItemDraft()];
  int _active = 0;

  // Income / transfer
  String _amountExpr = '';
  String _incomeCategory = 'salary';
  final _note = TextEditingController();
  bool _splitIncome = false;
  final _incomeSplit = SplitController();
  final _transferSplit = SplitController();

  @override
  void initState() {
    super.initState();
    final store = context.read<MoneyStore>();
    _bucketId = widget.bucketId ?? (store.buckets.isEmpty ? null : store.buckets.first.id);
    _prefillTransfer();
    // Split inputs affect validation of the whole form.
    _incomeSplit.addListener(_refresh);
    _transferSplit.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final i in _items) {
      i.note.dispose();
    }
    _note.dispose();
    _incomeSplit.dispose();
    _transferSplit.dispose();
    super.dispose();
  }

  MoneyStore get _store => context.read<MoneyStore>();

  Bucket? get _bucket => _store.bucket(_bucketId);

  List<Bucket> get _targets => _store.buckets.where((b) => b.id != _bucketId).toList();

  String get _expr => _mode == ComposerMode.expense ? _items[_active].expr : _amountExpr;

  int get _amount => Calculator.evaluateMinor(_expr) ?? 0;

  int get _expenseTotal =>
      // No `1 << n` bounds here: shifts are 32-bit on the web.
      _items.fold(0, (s, i) => s + math.max(0, Calculator.evaluateMinor(i.expr) ?? 0));

  void _onKey(String key) {
    setState(() {
      final next = Calculator.press(_expr, key);
      if (_mode == ComposerMode.expense) {
        _items[_active].expr = next;
      } else {
        _amountExpr = next;
      }
    });
  }

  void _prefillTransfer() {
    final b = _bucket;
    if (b == null) return;
    final ids = _targets.map((t) => t.id).toSet();
    final saved = Map.fromEntries(b.defaultSplit.entries.where((e) => ids.contains(e.key)));
    if (saved.isNotEmpty) {
      _transferSplit.prefill(saved);
      _incomeSplit.prefill(saved);
    } else {
      _incomeSplit.clear();
      if (ids.length == 1) {
        _transferSplit.prefill({ids.first: 10000});
      } else {
        _transferSplit.clear();
      }
    }
  }

  void _selectBucket(String id) {
    setState(() {
      _bucketId = id;
      _prefillTransfer();
    });
  }

  /// Returns a blocking error, or null when the form can be saved.
  String? _validate() {
    final fmt = context.read<SettingsStore>().format;
    final b = _bucket;
    if (b == null) return 'Create a bucket first';
    final ids = _targets.map((t) => t.id);
    switch (_mode) {
      case ComposerMode.expense:
        if (_items.any((i) => i.expr.isNotEmpty && Calculator.evaluateMinor(i.expr) == null)) {
          return 'One of the amounts is not valid';
        }
        if (_items.any((i) => (Calculator.evaluateMinor(i.expr) ?? 0) < 0)) {
          return 'Amounts cannot be negative';
        }
        if (_expenseTotal <= 0) return 'Enter an amount';
      case ComposerMode.income:
        if (_amount <= 0) return 'Enter an amount';
        if (_splitIncome && _incomeSplit.overAllocated(_amount, ids)) return 'Split is more than the amount';
      case ComposerMode.transfer:
        if (_targets.isEmpty) return 'Create another bucket to transfer to';
        if (_amount <= 0) return 'Enter an amount to split';
        if (_transferSplit.overAllocated(_amount, ids)) return 'Split is more than the amount';
        final moved = _transferSplit.shares(_amount, ids).values.fold(0, (s, v) => s + v);
        if (moved <= 0) return 'Choose how much goes to each bucket';
        final balance = _store.balanceOf(b.id);
        if (moved > balance) return 'Only ${fmt.format(balance)} available in ${b.name}';
    }
    return null;
  }

  void _save() {
    final b = _bucket!;
    final fmt = context.read<SettingsStore>().format;
    final ids = _targets.map((t) => t.id).toList();
    final store = _store;
    final String message;
    try {
      switch (_mode) {
        case ComposerMode.expense:
          final items = [
            for (final i in _items)
              ExpenseItem(
                amountMinor: Calculator.evaluateMinor(i.expr) ?? 0,
                categoryId: i.categoryId,
                note: i.note.text,
              ),
          ];
          final created = store.addExpenses(bucketId: b.id, items: items, date: _date);
          message = 'Spent ${fmt.format(_expenseTotal)} from ${b.name}'
              '${created.length > 1 ? ' (${created.length} items)' : ''}';
        case ComposerMode.income:
          final split = _splitIncome && _incomeSplit.mode == SplitMode.percent;
          store.addIncome(
            bucketId: b.id,
            amountMinor: _amount,
            shares: _splitIncome ? _incomeSplit.shares(_amount, ids) : const {},
            rememberSplitBp: split ? _incomeSplit.basisPoints(ids) : null,
            categoryId: _incomeCategory,
            note: _note.text,
            date: _date,
          );
          message = 'Added ${fmt.format(_amount)}${_splitIncome ? ' and split it' : ' to ${b.name}'}';
        case ComposerMode.transfer:
          final shares = _transferSplit.shares(_amount, ids);
          store.transfer(
            fromId: b.id,
            shares: shares,
            rememberSplitBp: _transferSplit.mode == SplitMode.percent ? _transferSplit.basisPoints(ids) : null,
            note: _note.text,
            date: _date,
          );
          message = 'Moved ${fmt.format(shares.values.fold(0, (s, v) => s + v))} from ${b.name}';
      }
    } on ArgumentError catch (e) {
      showMessage(context, '${e.message}');
      return;
    }
    showUndoSnack(context, message);
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day, now.hour, now.minute, now.second));
  }

  Color _modeColor(BuildContext context) {
    final c = MoneyColors.of(context);
    return switch (_mode) {
      ComposerMode.expense => c.expense,
      ComposerMode.income => c.income,
      ComposerMode.transfer => c.transfer,
    };
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final scheme = Theme.of(context).colorScheme;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final error = _validate();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
        titleSpacing: 0,
        title: SegmentedButton<ComposerMode>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: ComposerMode.expense, label: Text('Spend')),
            ButtonSegment(value: ComposerMode.income, label: Text('Add')),
            ButtonSegment(value: ComposerMode.transfer, label: Text('Transfer')),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        actions: const [SizedBox(width: 12)],
      ),
      body: store.buckets.isEmpty
          ? const EmptyState(emoji: '🪣', title: 'No buckets yet', message: 'Create a bucket on the Home screen first.')
          : Column(
              children: [
                // Pinned so the amount stays visible while the form scrolls.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: _AmountDisplay(
                    expr: _expr,
                    color: _modeColor(context),
                    caption: _mode == ComposerMode.expense && _items.length > 1
                        ? 'Item ${_active + 1} of ${_items.length}'
                        : null,
                    totalMinor: _mode == ComposerMode.expense && _items.length > 1 ? _expenseTotal : null,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    children: [
                      Row(
                        children: [
                          Text(
                            _mode == ComposerMode.income ? 'INTO' : 'FROM',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          ActionChip(
                            avatar: const Icon(Icons.event_rounded, size: 18),
                            label: Text(friendlyDay(_date)),
                            onPressed: _pickDate,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _BucketPicker(selectedId: _bucketId, onSelected: _selectBucket),
                      const SizedBox(height: 18),
                      ...switch (_mode) {
                        ComposerMode.expense => _expenseSection(context),
                        ComposerMode.income => _incomeSection(context),
                        ComposerMode.transfer => _transferSection(context),
                      },
                    ],
                  ),
                ),
                Material(
                  color: Theme.of(context).bottomSheetTheme.backgroundColor,
                  elevation: 8,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!keyboardOpen) Keypad(onKey: _onKey),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: _modeColor(context), foregroundColor: Colors.white),
                              onPressed: error == null ? _save : null,
                              icon: const Icon(Icons.check_rounded),
                              label: Text(error ?? switch (_mode) {
                                ComposerMode.expense => 'Save spend',
                                ComposerMode.income => 'Add money',
                                ComposerMode.transfer => 'Confirm transfer',
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _expenseSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = context.watch<SettingsStore>().format;
    final b = _bucket;
    final after = b == null ? 0 : _store.balanceOf(b.id) - _expenseTotal;
    return [
      const SectionHeader('Items'),
      for (var i = 0; i < _items.length; i++) _itemRow(context, i),
      const SizedBox(height: 4),
      OutlinedButton.icon(
        onPressed: () => setState(() {
          _items.add(_ItemDraft(categoryId: _items.last.categoryId));
          _active = _items.length - 1;
        }),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add another item'),
      ),
      if (b != null && _expenseTotal > 0 && after < 0)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: _Banner(
            icon: Icons.warning_amber_rounded,
            color: scheme.error,
            text: 'This takes ${b.name} below zero (${fmt.format(after)}).',
          ),
        ),
    ];
  }

  Widget _itemRow(BuildContext context, int i) {
    final item = _items[i];
    final scheme = Theme.of(context).colorScheme;
    final active = i == _active;
    final cat = categoryById(item.categoryId);
    final value = Calculator.evaluateMinor(item.expr);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? _modeColor(context) : scheme.outlineVariant.withValues(alpha: 0.4), width: active ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _active = i),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
            child: Row(
              children: [
                Tooltip(
                  message: cat.name,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      setState(() => _active = i);
                      final picked = await pickCategory(context, expense: true, selected: item.categoryId);
                      if (picked != null) setState(() => item.categoryId = picked);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: item.note,
                    onTap: () => setState(() => _active = i),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: cat.name,
                      filled: false,
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Text(
                  item.expr.isEmpty ? '0' : (value == null ? item.expr : context.watch<SettingsStore>().format.format(value)),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFeatures: tabular,
                      color: active ? _modeColor(context) : scheme.onSurface),
                ),
                if (_items.length > 1)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded, size: 18, color: scheme.onSurfaceVariant),
                    onPressed: () => setState(() {
                      _items.removeAt(i).note.dispose();
                      if (_active > i) _active--;
                      _active = _active.clamp(0, _items.length - 1);
                    }),
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _incomeSection(BuildContext context) {
    final b = _bucket;
    return [
      const SectionHeader('Source'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in incomeCategories)
            ChoiceChip(
              avatar: Text(c.emoji),
              label: Text(c.name),
              selected: _incomeCategory == c.id,
              onSelected: (_) => setState(() => _incomeCategory = c.id),
            ),
        ],
      ),
      const SizedBox(height: 14),
      _NoteField(controller: _note),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: const Text('Split this deposit', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('Send a share to other buckets; the rest stays here'),
        value: _splitIncome,
        onChanged: _targets.isEmpty ? null : (v) => setState(() => _splitIncome = v),
      ),
      if (_splitIncome && b != null)
        _Card(
          child: SplitEditor(
            controller: _incomeSplit,
            source: b,
            targets: _targets,
            amountMinor: _amount,
            remainderLabel: 'Stays in',
          ),
        ),
    ];
  }

  List<Widget> _transferSection(BuildContext context) {
    final b = _bucket;
    final scheme = Theme.of(context).colorScheme;
    return [
      if (b != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Text('Available', style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(width: 6),
              MoneyText(_store.balanceOf(b.id), style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: _store.balanceOf(b.id) > 0
                    ? () => setState(() => _amountExpr = (_store.balanceOf(b.id) / 100).toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), ''))
                    : null,
                child: const Text('Use all'),
              ),
            ],
          ),
        ),
      const SectionHeader('Split to'),
      if (b != null)
        _Card(
          child: SplitEditor(
            controller: _transferSplit,
            source: b,
            targets: _targets,
            amountMinor: _amount,
            remainderLabel: 'Stays in',
          ),
        ),
      const SizedBox(height: 14),
      _NoteField(controller: _note),
    ];
  }
}

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({required this.expr, required this.color, this.caption, this.totalMinor});

  final String expr;
  final Color color;
  final String? caption;
  final int? totalMinor;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final scheme = Theme.of(context).colorScheme;
    final value = Calculator.evaluateMinor(expr);
    final showResult = Calculator.hasOperator(expr) && value != null;

    return Column(
      children: [
        if (caption != null)
          Text(caption!, style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(settings.currency.symbol.trim(),
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.7))),
              const SizedBox(width: 4),
              Text(
                expr.isEmpty ? '0' : expr,
                style: TextStyle(fontSize: 54, fontWeight: FontWeight.w800, color: color, letterSpacing: -1.5, fontFeatures: tabular),
              ),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: showResult
              ? Text('= ${settings.format.format(value)}',
                  key: ValueKey(value),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant))
              : totalMinor != null
                  ? Text('Total ${settings.format.format(totalMinor!)}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant))
                  : const SizedBox(height: 20),
        ),
      ],
    );
  }
}

class _BucketPicker extends StatelessWidget {
  const _BucketPicker({required this.selectedId, required this.onSelected});

  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: store.buckets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final b = store.buckets[i];
          final selected = b.id == selectedId;
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onSelected(b.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
              decoration: BoxDecoration(
                color: selected ? b.color.withValues(alpha: 0.14) : Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? b.color : scheme.outlineVariant.withValues(alpha: 0.4), width: selected ? 2 : 1),
              ),
              child: Row(
                children: [
                  BucketAvatar(b, size: 40),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      MoneyText(store.balanceOf(b.id),
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        hintText: 'Add a note (optional)',
        prefixIcon: Icon(Icons.edit_note_rounded),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

/// Category grid sheet. Returns the chosen category id.
Future<String?> pickCategory(BuildContext context, {required bool expense, String? selected}) {
  final list = expense ? expenseCategories : incomeCategories;
  return showModalBottomSheet<String>(
    context: context,
    // The default sheet caps at 9/16 of the screen, which clips the last row.
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Category'),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.25,
              children: [
                for (final cat in list)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(c, cat.id),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: cat.id == selected ? 0.25 : 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: cat.id == selected ? Border.all(color: cat.color, width: 2) : null,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(cat.emoji, style: const TextStyle(fontSize: 26)),
                          const SizedBox(height: 6),
                          Text(cat.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
