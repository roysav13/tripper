import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/expenses/domain/expense.dart';
import 'package:tripper/features/expenses/domain/expense_grouping.dart';
import 'package:tripper/features/trips/domain/trip.dart';

const _tripNoDates = Trip(id: 't1', name: 'Thailand', destinations: ['Krabi']);

Trip _tripSpanning(int days) => Trip(
      id: 't1',
      name: 'Thailand',
      destinations: ['Krabi'],
      // June 1 anchor: avoids DST transitions (Mar 8 spring-forward, Nov 1 fall-back
      // in most zones), keeping tests independent of Trip.lengthInDays's pre-existing
      // DST bug which silently undercounts when a range crosses spring-forward.
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 6, days),
    );

Expense _expense({
  required String id,
  required DateTime date,
  int amountMinor = 1000,
  String currency = 'ILS',
  int? convertedAmountMinor,
  String? convertedCurrency,
}) =>
    Expense(
      id: id,
      tripId: 't1',
      amountMinor: amountMinor,
      currency: currency,
      category: ExpenseCategory.food,
      date: date,
      convertedAmountMinor: convertedAmountMinor,
      convertedCurrency: convertedCurrency,
    );

void main() {
  group('granularityFor', () {
    test('trip spanning 21 days or fewer groups by day', () {
      expect(granularityFor(_tripSpanning(1), []), ExpenseGroupGranularity.day);
      expect(
          granularityFor(_tripSpanning(21), []), ExpenseGroupGranularity.day,);
    });

    test('trip spanning 22 to 90 days groups by week', () {
      expect(
          granularityFor(_tripSpanning(22), []), ExpenseGroupGranularity.week,);
      expect(
          granularityFor(_tripSpanning(90), []), ExpenseGroupGranularity.week,);
    });

    test('trip spanning more than 90 days groups by month', () {
      expect(
          granularityFor(_tripSpanning(91), []), ExpenseGroupGranularity.month,);
    });

    test('falls back to the expense date spread when the trip has no dates',
        () {
      final shortSpread = [
        _expense(id: 'a', date: DateTime(2026, 3, 1)),
        _expense(id: 'b', date: DateTime(2026, 3, 5)),
      ];
      expect(granularityFor(_tripNoDates, shortSpread),
          ExpenseGroupGranularity.day,);

      final longSpread = [
        _expense(id: 'a', date: DateTime(2026, 1, 1)),
        _expense(id: 'b', date: DateTime(2026, 6, 1)),
      ];
      expect(granularityFor(_tripNoDates, longSpread),
          ExpenseGroupGranularity.month,);
    });

    test('no trip dates and no expenses defaults to day, does not crash', () {
      expect(granularityFor(_tripNoDates, []), ExpenseGroupGranularity.day);
    });

    test(
        'the expense-date-spread fallback is DST-safe (does not undercount '
        'a span crossing a spring-forward transition)',
        () {
          final expenses = [
            _expense(id: 'a', date: DateTime(2026, 1, 1)),
            _expense(id: 'b', date: DateTime(2026, 4, 1)),
            // crosses Mar DST in most zones
          ];
          // Jan 1 -> Apr 1 inclusive is 91 days, which must land in `month` (>90),
          // not silently undercount to 90 and land in `week`.
          expect(
            granularityFor(_tripNoDates, expenses),
            ExpenseGroupGranularity.month,
          );
        },
    );
  });

  group('groupExpenses', () {
    test('empty list produces no groups', () {
      expect(groupExpenses(_tripSpanning(5), [], ''), isEmpty);
    });

    test(
        'groups same-day expenses together, newest group first, regardless '
        'of input order', () {
      final expenses = [
        _expense(id: 'day1-a', date: DateTime(2026, 3, 1)),
        _expense(id: 'day2-a', date: DateTime(2026, 3, 2)),
        _expense(id: 'day1-b', date: DateTime(2026, 3, 1)),
      ];
      final groups = groupExpenses(_tripSpanning(5), expenses, '');
      expect(groups, hasLength(2));
      expect(groups[0].periodStart, DateTime(2026, 3, 2));
      expect(groups[0].expenses.map((e) => e.id), ['day2-a']);
      expect(groups[1].periodStart, DateTime(2026, 3, 1));
      expect(groups[1].expenses.map((e) => e.id), ['day1-a', 'day1-b']);
    });

    test('groups by week when the trip spans 22-90 days', () {
      final expenses = [
        _expense(id: 'a', date: DateTime(2026, 3, 2)), // Monday
        _expense(id: 'b', date: DateTime(2026, 3, 4)), // same week, Wed
        _expense(id: 'c', date: DateTime(2026, 3, 9)), // next Monday
      ];
      final groups = groupExpenses(_tripSpanning(30), expenses, '');
      expect(groups, hasLength(2));
      expect(groups[0].granularity, ExpenseGroupGranularity.week);
      expect(groups[0].periodStart, DateTime(2026, 3, 9));
      expect(groups[1].periodStart, DateTime(2026, 3, 2));
    });

    test('groups by month when the trip spans more than 90 days', () {
      final expenses = [
        _expense(id: 'a', date: DateTime(2026, 3, 15)),
        _expense(id: 'b', date: DateTime(2026, 4, 2)),
      ];
      final groups = groupExpenses(_tripSpanning(100), expenses, '');
      expect(groups, hasLength(2));
      expect(groups[0].periodStart, DateTime(2026, 4, 1));
      expect(groups[1].periodStart, DateTime(2026, 3, 1));
    });

    test('per-currency totals are computed per group, not across groups', () {
      final expenses = [
        _expense(
            id: 'a',
            date: DateTime(2026, 3, 1),
            amountMinor: 1000,
            currency: 'ILS',),
        _expense(
            id: 'b',
            date: DateTime(2026, 3, 1),
            amountMinor: 500,
            currency: 'USD',),
        _expense(
            id: 'c',
            date: DateTime(2026, 3, 2),
            amountMinor: 300,
            currency: 'ILS',),
      ];
      final groups = groupExpenses(_tripSpanning(5), expenses, '');
      final day2 =
          groups.firstWhere((g) => g.periodStart == DateTime(2026, 3, 2));
      expect(day2.perCurrencyTotals, [(currency: 'ILS', amountMinor: 300)]);
      final day1 =
          groups.firstWhere((g) => g.periodStart == DateTime(2026, 3, 1));
      expect(day1.perCurrencyTotals, hasLength(2));
    });

    test('homeCurrencyTotal is null when no home currency is set', () {
      final groups = groupExpenses(
        _tripSpanning(5),
        [_expense(id: 'a', date: DateTime(2026, 3, 1))],
        '',
      );
      expect(groups.single.homeCurrencyTotal, isNull);
    });

    test(
        'homeCurrencyTotal is null for a single-currency group even with a '
        'home currency set — matches ExpenseSummaryCard\'s own rule that a '
        'single-currency total needs no second, redundant \'converted\' line',
        () {
      final groups = groupExpenses(
        _tripSpanning(5),
        [
          _expense(
              id: 'a',
              date: DateTime(2026, 3, 1),
              amountMinor: 1000,
              currency: 'ILS',),
          _expense(
              id: 'b',
              date: DateTime(2026, 3, 1),
              amountMinor: 500,
              currency: 'ILS',),
        ],
        'ILS',
      );
      expect(groups.single.homeCurrencyTotal, isNull);
    });

    test(
        'homeCurrencyTotal sums converted + native amounts and counts '
        'pending, per group, only when that group mixes currencies', () {
      final expenses = [
        _expense(
            id: 'a',
            date: DateTime(2026, 3, 1),
            amountMinor: 10000,
            currency: 'ILS',),
        _expense(
          id: 'b',
          date: DateTime(2026, 3, 1),
          amountMinor: 2700,
          currency: 'USD',
          convertedAmountMinor: 10000,
          convertedCurrency: 'ILS',
        ),
        _expense(
            id: 'c',
            date: DateTime(2026, 3, 1),
            amountMinor: 500,
            currency: 'EUR',),
      ];
      final group = groupExpenses(_tripSpanning(5), expenses, 'ILS').single;
      expect(group.homeCurrencyTotal!.amountMinor, 20000);
      expect(group.homeCurrencyTotal!.pendingCount, 1);
      expect(group.homeCurrency, 'ILS');
    });
  });
}
