import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/expenses/domain/exchange_rates.dart';

final _fetchedAt = DateTime(2026, 7, 23, 9);

/// Base ILS: 1 ILS = 0.27 USD = 0.25 EUR.
final _rates = ExchangeRateSnapshot(
  base: 'ILS',
  rates: const {'USD': 0.27, 'EUR': 0.25},
  fetchedAt: _fetchedAt,
);

void main() {
  group('rateFor', () {
    test('identity is 1 even for an unknown currency', () {
      expect(_rates.rateFor('XYZ', 'XYZ'), 1);
    });

    test('base to quoted, and quoted to base', () {
      expect(_rates.rateFor('ILS', 'USD'), closeTo(0.27, 1e-9));
      expect(_rates.rateFor('USD', 'ILS'), closeTo(1 / 0.27, 1e-9));
    });

    test('cross rate between two quoted currencies', () {
      // 1 USD = (1/0.27) ILS = 0.9259 EUR
      expect(_rates.rateFor('USD', 'EUR'), closeTo(0.25 / 0.27, 1e-9));
    });

    test('null when either side is unknown — never a guess', () {
      expect(_rates.rateFor('THB', 'ILS'), isNull);
      expect(_rates.rateFor('ILS', 'THB'), isNull);
    });
  });

  group('convertMinor', () {
    test('converts and rounds to whole minor units', () {
      // 100.00 USD -> ILS at 1/0.27 = 370.37...
      expect(convertMinor(10000, 'USD', 'ILS', _rates), 37037);
    });

    test('same currency is a passthrough, not a rate lookup', () {
      expect(convertMinor(1234, 'ILS', 'ILS', _rates), 1234);
    });

    test('unknown currency yields null, not zero', () {
      expect(convertMinor(10000, 'THB', 'ILS', _rates), isNull);
    });
  });

  group('convertedTotalMinor', () {
    test('sums mixed currencies into the target', () {
      final total = convertedTotalMinor(
        const [
          (currency: 'ILS', amountMinor: 10000),
          (currency: 'USD', amountMinor: 2700),
        ],
        'ILS',
        _rates,
      );
      // 100.00 ILS + (27.00 USD -> 100.00 ILS) = 200.00
      expect(total, 20000);
    });

    test(
        'returns null if ANY line is unconvertible — a partial total '
        'that silently drops a currency is the bug this feature fixes', () {
      final total = convertedTotalMinor(
        const [
          (currency: 'ILS', amountMinor: 10000),
          (currency: 'THB', amountMinor: 50000),
        ],
        'ILS',
        _rates,
      );
      expect(total, isNull);
    });
  });

  group('isStale', () {
    test('fresh within the window, stale past it', () {
      expect(
        _rates.isStale(
          _fetchedAt.add(const Duration(hours: 6)),
          const Duration(hours: 12),
        ),
        isFalse,
      );
      expect(
        _rates.isStale(
          _fetchedAt.add(const Duration(hours: 13)),
          const Duration(hours: 12),
        ),
        isTrue,
      );
    });
  });
}
