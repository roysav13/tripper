import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/expenses/domain/expense.dart';

Expense _expense({
  String id = 'e1',
  int amountMinor = 1000,
  ExpenseCategory category = ExpenseCategory.food,
  String currency = 'ILS',
}) =>
    Expense(
      id: id,
      tripId: 't1',
      amountMinor: amountMinor,
      currency: currency,
      category: category,
      date: DateTime(2026, 8, 1),
    );

void main() {
  group('parseAmountToMinor', () {
    test('whole numbers, one decimal, two decimals', () {
      expect(parseAmountToMinor('12'), 1200);
      expect(parseAmountToMinor('12.3'), 1230);
      expect(parseAmountToMinor('12.30'), 1230);
      expect(parseAmountToMinor('0.05'), 5);
      expect(parseAmountToMinor('0'), 0);
    });

    test('comma decimal separator (European keyboards)', () {
      expect(parseAmountToMinor('12,30'), 1230);
    });

    test('surrounding whitespace is tolerated', () {
      expect(parseAmountToMinor('  12.30  '), 1230);
    });

    test('rejects junk, negatives, and over-precise input', () {
      expect(parseAmountToMinor(''), isNull);
      expect(parseAmountToMinor('abc'), isNull);
      expect(parseAmountToMinor('-5'), isNull);
      expect(parseAmountToMinor('12.345'), isNull);
      expect(parseAmountToMinor('1.2.3'), isNull);
      expect(parseAmountToMinor('12 30'), isNull);
    });
  });

  group('formatMinor', () {
    test('always two decimals so mono columns align', () {
      expect(formatMinor(1230), '12.30');
      expect(formatMinor(1200), '12.00');
      expect(formatMinor(5), '0.05');
      expect(formatMinor(0), '0.00');
    });

    test('round-trips with parseAmountToMinor', () {
      for (final input in ['0.01', '7.00', '123.45', '9999.99']) {
        expect(formatMinor(parseAmountToMinor(input)!), input);
      }
    });
  });

  group('totalMinor', () {
    test('sums exactly — integer arithmetic, no float drift', () {
      // 0.1 + 0.2 in floats is famously 0.30000000000000004.
      final expenses = [
        _expense(id: 'a', amountMinor: 10),
        _expense(id: 'b', amountMinor: 20),
      ];
      expect(totalMinor(expenses), 30);
      expect(formatMinor(totalMinor(expenses)), '0.30');
    });

    test('empty list totals zero', () {
      expect(totalMinor(const []), 0);
    });
  });

  group('totalsByCurrency (mixed-currency trips must never be summed)', () {
    test('single currency yields one line', () {
      final rows = totalsByCurrency([
        _expense(id: 'a', amountMinor: 1250),
        _expense(id: 'b', amountMinor: 750),
      ]);
      expect(rows, hasLength(1));
      expect(rows.single.currency, 'ILS');
      expect(rows.single.amountMinor, 2000);
    });

    test(
        'ILS + USD stay separate — the real bug: 100 ILS + 50 USD was '
        'reported as 150 of one currency', () {
      final rows = totalsByCurrency([
        _expense(id: 'a', amountMinor: 10000, currency: 'ILS'),
        _expense(id: 'b', amountMinor: 5000, currency: 'USD'),
      ]);
      expect(rows, hasLength(2));
      expect(
        {for (final r in rows) r.currency: r.amountMinor},
        {'ILS': 10000, 'USD': 5000},
      );
    });

    test(
        'ordered by expense count (the trip\'s main currency first), '
        'never by amount across currencies', () {
      final rows = totalsByCurrency([
        // USD has the larger amount but only one expense.
        _expense(id: 'a', amountMinor: 100000, currency: 'USD'),
        _expense(id: 'b', amountMinor: 100, currency: 'ILS'),
        _expense(id: 'c', amountMinor: 100, currency: 'ILS'),
      ]);
      expect(rows.first.currency, 'ILS');
    });

    test('empty list yields no rows', () {
      expect(totalsByCurrency(const []), isEmpty);
    });
  });

  group('usesMultipleCurrencies', () {
    test('false for empty and single-currency, true for mixed', () {
      expect(usesMultipleCurrencies(const []), isFalse);
      expect(usesMultipleCurrencies([_expense()]), isFalse);
      expect(
        usesMultipleCurrencies([
          _expense(id: 'a', currency: 'ILS'),
          _expense(id: 'b', currency: 'USD'),
        ]),
        isTrue,
      );
    });
  });

  group('categoryBreakdown', () {
    test('groups by category, biggest first, within one currency', () {
      final expenses = [
        _expense(id: 'a', amountMinor: 500, category: ExpenseCategory.food),
        _expense(id: 'b', amountMinor: 2000, category: ExpenseCategory.stay),
        _expense(id: 'c', amountMinor: 700, category: ExpenseCategory.food),
      ];
      final rows = categoryBreakdown(expenses);
      expect(rows, hasLength(2));
      expect(rows.first.category, ExpenseCategory.stay);
      expect(rows.first.amounts.single.amountMinor, 2000);
      expect(rows[1].category, ExpenseCategory.food);
      expect(rows[1].amounts.single.amountMinor, 1200);
    });

    test('a category holding two currencies lists both, unsummed', () {
      final rows = categoryBreakdown([
        _expense(id: 'a', amountMinor: 1000, currency: 'ILS'),
        _expense(id: 'b', amountMinor: 500, currency: 'USD'),
      ]);
      expect(rows, hasLength(1));
      expect(
        {for (final a in rows.single.amounts) a.currency: a.amountMinor},
        {'ILS': 1000, 'USD': 500},
      );
    });

    test(
        'mixed-currency trips fall back to stable enum order — ranking '
        'across currencies would need rates the app does not have', () {
      final rows = categoryBreakdown([
        _expense(
          id: 'a',
          amountMinor: 100,
          currency: 'USD',
          category: ExpenseCategory.shopping,
        ),
        _expense(
          id: 'b',
          amountMinor: 999999,
          currency: 'ILS',
          category: ExpenseCategory.transport,
        ),
      ]);
      // transport (index 0) before shopping (index 4), regardless of size.
      expect(rows.map((r) => r.category), [
        ExpenseCategory.transport,
        ExpenseCategory.shopping,
      ]);
    });

    test('categories with no spend are omitted entirely', () {
      expect(categoryBreakdown([_expense()]), hasLength(1));
    });

    test('empty list yields an empty breakdown', () {
      expect(categoryBreakdown(const []), isEmpty);
    });
  });

  group('homeTotal (stored conversions, M5.5b)', () {
    Expense converted({
      required String id,
      int amountMinor = 2700,
      String currency = 'USD',
      int? convertedAmountMinor,
      String? convertedCurrency,
      DateTime? rateAt,
    }) =>
        Expense(
          id: id,
          tripId: 't1',
          amountMinor: amountMinor,
          currency: currency,
          category: ExpenseCategory.food,
          date: DateTime(2026, 8, 1),
          convertedAmountMinor: convertedAmountMinor,
          convertedCurrency: convertedCurrency,
          convertedRateAt: rateAt,
        );

    test('native + converted amounts combine into one figure', () {
      final result = homeTotal(
        [
          converted(id: 'a', amountMinor: 10000, currency: 'ILS'),
          converted(
            id: 'b',
            convertedAmountMinor: 10000,
            convertedCurrency: 'ILS',
          ),
        ],
        'ILS',
      );
      expect(result.amountMinor, 20000);
      expect(result.pendingCount, 0);
    });

    test(
        'unconverted expenses are counted as pending, never silently '
        'dropped from the total', () {
      final result = homeTotal(
        [
          converted(id: 'a', amountMinor: 10000, currency: 'ILS'),
          converted(id: 'b'), // USD, no conversion stored
        ],
        'ILS',
      );
      expect(result.amountMinor, 10000);
      expect(result.pendingCount, 1);
    });

    test('a conversion into a different home currency does not count', () {
      final result = homeTotal(
        [
          converted(
            id: 'a',
            convertedAmountMinor: 5000,
            convertedCurrency: 'EUR',
          ),
        ],
        'ILS',
      );
      expect(result.amountMinor, 0);
      expect(result.pendingCount, 1);
    });

    test(
        'reports the oldest rate timestamp — the total is only as fresh '
        'as its stalest input', () {
      final older = DateTime(2026, 7, 1);
      final newer = DateTime(2026, 7, 20);
      final result = homeTotal(
        [
          converted(
            id: 'a',
            convertedAmountMinor: 1,
            convertedCurrency: 'ILS',
            rateAt: newer,
          ),
          converted(
            id: 'b',
            convertedAmountMinor: 1,
            convertedCurrency: 'ILS',
            rateAt: older,
          ),
        ],
        'ILS',
      );
      expect(result.ratesAt, older);
    });
  });

  group('needingConversion', () {
    test('lists only what is missing a usable home-currency value', () {
      final expenses = [
        _expense(id: 'native', currency: 'ILS'),
        _expense(id: 'pending', currency: 'USD'),
      ];
      expect(
        needingConversion(expenses, 'ILS').map((e) => e.id),
        ['pending'],
      );
    });
  });

  group('tripCurrency (what the add-expense form pre-fills)', () {
    test(
        'null when there are no expenses yet (form asks instead of '
        'assuming)', () {
      expect(tripCurrency(const []), isNull);
    });

    test('takes the currency already in use for the trip', () {
      expect(tripCurrency([_expense(currency: 'THB')]), 'THB');
    });

    test('picks the most-used currency, not the first entered', () {
      expect(
        tripCurrency([
          _expense(id: 'a', currency: 'USD'),
          _expense(id: 'b', currency: 'ILS'),
          _expense(id: 'c', currency: 'ILS'),
        ]),
        'ILS',
      );
    });
  });
}
