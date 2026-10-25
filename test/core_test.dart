import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/calculator.dart';
import 'package:money_manager/core/money.dart';
import 'package:money_manager/core/split.dart';

String typeKeys(String keys) {
  var e = '';
  for (final k in keys.split('')) {
    e = Calculator.press(e, k);
  }
  return e;
}

void main() {
  group('parseMinor', () {
    test('parses whole and decimal amounts', () {
      expect(parseMinor('12'), 1200);
      expect(parseMinor('12.5'), 1250);
      expect(parseMinor('12.05'), 1205);
      expect(parseMinor('.5'), 50);
      expect(parseMinor('1,23,456.78'), 12345678);
    });

    test('rejects junk the original app accepted', () {
      expect(parseMinor('12abc'), isNull);
      expect(parseMinor('1.234'), isNull);
      expect(parseMinor('-5'), isNull);
      expect(parseMinor(''), isNull);
    });
  });

  group('MoneyFormat', () {
    test('rupees use Indian lakh grouping', () {
      final f = MoneyFormat(Currency.byCode('INR'));
      expect(f.format(12345678), '₹1,23,456.78');
      expect(f.format(-5000), '−₹50.00');
      expect(f.format(5000, signed: true), '+₹50.00');
      expect(f.format(5000, dropZeroDecimals: true), '₹50');
    });

    test('dollars use western grouping', () {
      final f = MoneyFormat(Currency.byCode('USD'));
      expect(f.format(12345678), r'$123,456.78');
    });
  });

  group('Calculator', () {
    test('typing rules', () {
      expect(typeKeys('007'), '7');
      expect(typeKeys('.5'), '0.5');
      expect(typeKeys('1.234'), '1.23');
      expect(typeKeys('1..2'), '1.2');
      expect(typeKeys('5+×3'), '5×3');
      expect(typeKeys('+5'), '5');
    });

    test('evaluates with precedence', () {
      expect(Calculator.evaluateMinor('450+120×2'), 69000);
      expect(Calculator.evaluateMinor('100÷4−5'), 2000);
      expect(Calculator.evaluateMinor('10+'), 1000);
      expect(Calculator.evaluateMinor('0.1+0.2'), 30);
      expect(Calculator.evaluateMinor('5÷0'), isNull);
      expect(Calculator.evaluateMinor(''), isNull);
    });
  });

  group('split', () {
    test('shares are floored so they never exceed the amount', () {
      final shares = splitByBasisPoints(10000, {'a': 3333, 'b': 3333, 'c': 3334});
      expect(shares.values.reduce((a, b) => a + b), lessThanOrEqualTo(10000));
      expect(shares['a'], 3333);
    });

    test('100% to one target moves the whole amount', () {
      expect(splitByBasisPoints(12345, {'a': 10000}), {'a': 12345});
    });

    test('equal basis points always sum to 100%', () {
      expect(equalBasisPoints(3), [3334, 3333, 3333]);
      expect(equalBasisPoints(3).reduce((a, b) => a + b), fullBasisPoints);
      expect(percentToBasisPoints(12.5), 1250);
    });
  });
}
