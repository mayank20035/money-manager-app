/// Pure logic behind the calculator keypad. Expressions use the display
/// operators `+ − × ÷` and are evaluated with normal precedence.
class Calculator {
  Calculator._();

  static const operators = ['+', '−', '×', '÷'];
  static const maxLength = 32;

  static bool isOperator(String ch) => operators.contains(ch);

  /// True when the expression contains an operator (i.e. shows a live result).
  static bool hasOperator(String expr) =>
      expr.split('').skip(1).any(isOperator);

  /// Applies one key press. Keys: digits, `.`, operators, `⌫` (backspace), `C` (clear).
  static String press(String expr, String key) {
    if (key == 'C') return '';
    if (key == '⌫') return expr.isEmpty ? expr : expr.substring(0, expr.length - 1);
    if (expr.length >= maxLength) return expr;

    final last = expr.isEmpty ? '' : expr[expr.length - 1];
    final current = _currentNumber(expr);

    if (isOperator(key)) {
      if (expr.isEmpty) return expr;
      if (isOperator(last)) return expr.substring(0, expr.length - 1) + key;
      if (last == '.') return '${expr.substring(0, expr.length - 1)}$key';
      return expr + key;
    }

    if (key == '.') {
      if (current.contains('.')) return expr;
      return expr + (current.isEmpty ? '0.' : '.');
    }

    // Digit.
    final dot = current.indexOf('.');
    if (dot >= 0 && current.length - dot - 1 >= 2) return expr; // max 2 decimals
    if (current == '0') return expr.substring(0, expr.length - 1) + key;
    if (dot < 0 && current.length >= 10) return expr; // keep numbers sane
    return expr + key;
  }

  static String _currentNumber(String expr) {
    var i = expr.length;
    while (i > 0 && !isOperator(expr[i - 1])) {
      i--;
    }
    return expr.substring(i);
  }

  /// Evaluates the expression into minor units. A trailing operator is ignored.
  /// Returns null for empty/invalid input or division by zero.
  static int? evaluateMinor(String expr) {
    var s = expr;
    while (s.isNotEmpty && isOperator(s[s.length - 1])) {
      s = s.substring(0, s.length - 1);
    }
    if (s.isEmpty) return null;

    final numbers = <double>[];
    final ops = <String>[];
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      if (isOperator(ch)) {
        final n = double.tryParse(buf.toString());
        if (n == null) return null;
        numbers.add(n);
        ops.add(ch);
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    final tail = double.tryParse(buf.toString());
    if (tail == null) return null;
    numbers.add(tail);

    // First pass: × and ÷.
    final terms = <double>[numbers.first];
    final addOps = <String>[];
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final n = numbers[i + 1];
      if (op == '×') {
        terms[terms.length - 1] *= n;
      } else if (op == '÷') {
        if (n == 0) return null;
        terms[terms.length - 1] /= n;
      } else {
        terms.add(n);
        addOps.add(op);
      }
    }
    // Second pass: + and −.
    var result = terms.first;
    for (var i = 0; i < addOps.length; i++) {
      result = addOps[i] == '+' ? result + terms[i + 1] : result - terms[i + 1];
    }
    if (result.isNaN || result.isInfinite) return null;
    return (result * 100).round();
  }
}
