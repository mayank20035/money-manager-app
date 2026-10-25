import 'package:flutter/material.dart';

import '../widgets/common.dart';

/// Calculator keypad. Emits keys understood by `Calculator.press`.
class Keypad extends StatelessWidget {
  const Keypad({super.key, required this.onKey});

  final ValueChanged<String> onKey;

  static const _rows = [
    ['7', '8', '9', '÷'],
    ['4', '5', '6', '×'],
    ['1', '2', '3', '−'],
    ['.', '0', '⌫', '+'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in _rows)
          Row(
            children: [
              for (final k in row) Expanded(child: _Key(label: k, onKey: onKey)),
            ],
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onKey});

  final String label;
  final ValueChanged<String> onKey;

  bool get _isOp => const ['÷', '×', '−', '+'].contains(label);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = _isOp ? scheme.primary : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: _isOp ? scheme.primaryContainer.withValues(alpha: 0.55) : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            tapFeedback(context);
            onKey(label);
          },
          onLongPress: label == '⌫'
              ? () {
                  tapFeedback(context);
                  onKey('C');
                }
              : null,
          child: SizedBox(
            height: 50,
            child: Center(
              child: label == '⌫'
                  ? Icon(Icons.backspace_outlined, color: fg, size: 22)
                  : Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: fg)),
            ),
          ),
        ),
      ),
    );
  }
}
