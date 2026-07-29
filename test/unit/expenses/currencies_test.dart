import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/expenses/domain/currencies.dart';
import 'package:tripper/features/expenses/domain/exchange_rates.dart';
import 'package:tripper/features/expenses/domain/expense.dart';

void main() {
  group('catalogue integrity', () {
    test('codes are unique, uppercase, and 3 letters', () {
      final codes = kCurrencies.map((c) => c.code).toList();
      expect(codes.toSet().length, codes.length, reason: 'duplicate code');
      for (final code in codes) {
        expect(RegExp(r'^[A-Z]{3}$').hasMatch(code), isTrue, reason: code);
      }
    });

    test('every entry has a name and symbol', () {
      for (final c in kCurrencies) {
        expect(c.name.trim(), isNotEmpty, reason: c.code);
        expect(c.symbol.trim(), isNotEmpty, reason: c.code);
      }
    });

    test(
        'minorDigits is 0 or 2 — anything else would need format and '
        'conversion changes', () {
      for (final c in kCurrencies) {
        expect(c.minorDigits, anyOf(0, 2), reason: c.code);
      }
    });
  });

  group('lookup', () {
    test('is case- and whitespace-insensitive', () {
      expect(currencyFor(' ils ')?.code, 'ILS');
      expect(isSupportedCurrency('usd'), isTrue);
    });

    test(
        'rejects non-ISO input that a free-text field would have '
        'accepted (NIS is a common wrong answer for the shekel)', () {
      expect(isSupportedCurrency('NIS'), isFalse);
      expect(currencyFor('NIS'), isNull);
      expect(isSupportedCurrency(''), isFalse);
      expect(isSupportedCurrency('XXX'), isFalse);
    });

    test(
        'unknown codes fall back to 2 decimals rather than throwing — '
        'rows saved before the picker existed still render', () {
      expect(minorDigitsFor('ZZZ'), 2);
    });
  });

  group('searchCurrencies', () {
    test('matches code, name, and symbol', () {
      expect(searchCurrencies('ILS').single.code, 'ILS');
      expect(searchCurrencies('shekel').single.code, 'ILS');
      expect(searchCurrencies('₪').single.code, 'ILS');
    });

    test('empty query returns everything; no match returns nothing', () {
      expect(searchCurrencies('   ').length, kCurrencies.length);
      expect(searchCurrencies('zzzzz'), isEmpty);
    });
  });

  group('zero-decimal currencies (JPY, KRW, VND)', () {
    test('format without a decimal point', () {
      expect(formatMinor(1000, digits: 0), '1000');
      expect(formatMinor(1000, digits: 2), '10.00');
    });

    test('parse whole numbers only, rejecting typed decimals', () {
      expect(parseAmountToMinor('1000', digits: 0), 1000);
      expect(parseAmountToMinor('10.50', digits: 0), isNull);
    });

    test('parse still handles 2-decimal currencies as before', () {
      expect(parseAmountToMinor('12.30', digits: 2), 1230);
      expect(parseAmountToMinor('12,30', digits: 2), 1230);
      expect(parseAmountToMinor('12.345', digits: 2), isNull);
    });

    test(
        'conversion rescales across differing decimal places — without '
        'this, JPY <-> ILS would be wrong by 100x', () {
      // 1 JPY = 0.025 ILS.
      final rates = ExchangeRateSnapshot(
        base: 'JPY',
        rates: const {'ILS': 0.025},
        fetchedAt: DateTime(2026, 7, 23),
      );
      // ¥1000 (1000 minor, 0 digits) -> ₪25.00 (2500 minor, 2 digits).
      expect(convertMinor(1000, 'JPY', 'ILS', rates), 2500);
      // And back: ₪25.00 -> ¥1000.
      expect(convertMinor(2500, 'ILS', 'JPY', rates), 1000);
    });

    test('conversion between two 2-decimal currencies is unscaled', () {
      final rates = ExchangeRateSnapshot(
        base: 'ILS',
        rates: const {'USD': 0.27},
        fetchedAt: DateTime(2026, 7, 23),
      );
      expect(convertMinor(10000, 'ILS', 'USD', rates), 2700);
    });
  });
}
