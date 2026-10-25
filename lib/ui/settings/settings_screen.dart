import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../state/money_store.dart';
import '../../state/settings_store.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final store = context.watch<MoneyStore>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          const SectionHeader('Appearance'),
          _Group(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('Auto')),
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => settings.themeMode = s.first,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in accentChoices)
                    GestureDetector(
                      onTap: () => settings.accent = c,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c.toARGB32() == settings.accent.toARGB32() ? scheme.onSurface : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: c.toARGB32() == settings.accent.toARGB32()
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ]),
          const SectionHeader('Money'),
          _Group(children: [
            ListTile(
              leading: const Icon(Icons.currency_exchange_rounded),
              title: const Text('Currency'),
              subtitle: Text('${settings.currency.name} (${settings.currency.symbol.trim()})'),
              onTap: () => _pickCurrency(context, settings),
            ),
            ListTile(
              leading: const Icon(Icons.pie_chart_outline_rounded),
              title: const Text('Monthly spending budget'),
              subtitle: Text(settings.monthlyBudgetMinor == null
                  ? 'Not set'
                  : settings.format.format(settings.monthlyBudgetMinor!, dropZeroDecimals: true)),
              onTap: () => _editBudget(context, settings),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.visibility_off_rounded),
              title: const Text('Hide amounts'),
              subtitle: const Text('Mask balances when others can see your screen'),
              value: settings.hideAmounts,
              onChanged: (v) => settings.hideAmounts = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.vibration_rounded),
              title: const Text('Haptic feedback'),
              value: settings.haptics,
              onChanged: (v) => settings.haptics = v,
            ),
          ]),
          const SectionHeader('Your data'),
          _Group(children: [
            ListTile(
              leading: const Icon(Icons.backup_rounded),
              title: const Text('Back up'),
              subtitle: const Text('Copy a full backup to the clipboard'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: store.exportJson()));
                if (context.mounted) showMessage(context, 'Backup copied — paste it somewhere safe');
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: const Text('Restore'),
              subtitle: const Text('Paste a backup to replace current data'),
              onTap: () => _restore(context, store),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Export CSV'),
              subtitle: Text('${store.txns.length} entries, for spreadsheets'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: store.exportCsv()));
                if (context.mounted) showMessage(context, 'CSV copied to the clipboard');
              },
            ),
            ListTile(
              leading: Icon(Icons.restart_alt_rounded, color: scheme.error),
              title: Text('Reset everything', style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
              subtitle: const Text('Delete all buckets and history'),
              onTap: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Reset everything?',
                  message: 'All buckets and history will be deleted and the two starter buckets recreated.',
                  confirm: 'Reset',
                );
                if (ok && context.mounted) {
                  store.resetAll();
                  showUndoSnack(context, 'Everything was reset');
                }
              },
            ),
          ]),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Money Manager 2.0 · Flutter\nYour data stays on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCurrency(BuildContext context, SettingsStore settings) async {
    final picked = await showModalBottomSheet<Currency>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final cur in Currency.all)
              ListTile(
                leading: CircleAvatar(child: Text(cur.symbol.trim().characters.first)),
                title: Text(cur.name),
                subtitle: Text(MoneyFormat(cur).format(12345678)),
                trailing: cur.code == settings.currency.code ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(c, cur),
              ),
          ],
        ),
      ),
    );
    if (picked != null) settings.currency = picked;
  }

  Future<void> _editBudget(BuildContext context, SettingsStore settings) async {
    final ctrl = TextEditingController(
        text: settings.monthlyBudgetMinor == null ? '' : minorToInput(settings.monthlyBudgetMinor!));
    final result = await showDialog<int?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Monthly budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How much do you want to spend at most each month? Leave empty to turn it off.'),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,10}(\.\d{0,2})?'))],
              decoration: InputDecoration(prefixText: settings.currency.symbol),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(c, parseMinor(ctrl.text) ?? 0),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) settings.monthlyBudgetMinor = result;
  }

  Future<void> _restore(BuildContext context, MoneyStore store) async {
    final ctrl = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Restore backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This replaces all current buckets and history.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 6,
              minLines: 4,
              decoration: InputDecoration(
                hintText: 'Paste backup here',
                suffixIcon: IconButton(
                  tooltip: 'Paste',
                  icon: const Icon(Icons.content_paste_rounded),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) ctrl.text = data!.text!;
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(c, ctrl.text),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (raw == null || raw.trim().isEmpty || !context.mounted) return;
    try {
      store.importJson(raw);
      showUndoSnack(context, 'Backup restored');
    } on FormatException catch (e) {
      showMessage(context, e.message);
    }
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}
