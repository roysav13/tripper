import 'package:flutter/foundation.dart';

import '../../trips/domain/trip.dart';
import 'expense.dart';

/// Which calendar period the Spend tab buckets expenses into — chosen
/// automatically per trip (see [granularityFor]), not user-toggleable.
enum ExpenseGroupGranularity { day, week, month }

/// Starting thresholds for [granularityFor] — like every other tunable
/// constant in this codebase, meant for on-device tuning once it's visible
/// against a real trip.
const _weekGranularityMaxDays = 21;
const _monthGranularityMaxDays = 90;

/// Which granularity the Spend tab should group at, based on how long the
/// trip spans. Uses [Trip.startDate]/[Trip.endDate] when both are set (the
/// trip's planned span); falls back to the actual spread of [expenses]'
/// dates (oldest to newest, inclusive) when either date is missing, so
/// grouping still degrades sensibly for trips created before start/end
/// dates were required.
ExpenseGroupGranularity granularityFor(Trip trip, List<Expense> expenses) {
  final span = trip.lengthInDays ?? _expenseDateSpanInDays(expenses);
  if (span <= _weekGranularityMaxDays) return ExpenseGroupGranularity.day;
  if (span <= _monthGranularityMaxDays) return ExpenseGroupGranularity.week;
  return ExpenseGroupGranularity.month;
}

int _expenseDateSpanInDays(List<Expense> expenses) {
  if (expenses.isEmpty) return 0;
  final dates = expenses.map((e) => _dateOnly(e.date));
  final earliest = dates.reduce((a, b) => a.isBefore(b) ? a : b);
  final latest = dates.reduce((a, b) => a.isAfter(b) ? a : b);
  return _epochDay(latest) - _epochDay(earliest) + 1;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Days since the Unix epoch, computed via UTC so this is immune to DST —
/// unlike `DateTime.difference().inDays` on local-zone DateTimes, which
/// silently undercounts by a day whenever the range crosses a DST
/// transition (one "day" in between is only 23 real hours, and .inDays
/// truncates the resulting non-whole-day Duration down).
int _epochDay(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;

/// One period's worth of expenses, ready for the Spend tab's collapsible
/// group headers.
@immutable
class ExpenseGroup {
  const ExpenseGroup({
    required this.granularity,
    required this.periodStart,
    required this.expenses,
    required this.perCurrencyTotals,
    required this.homeCurrency,
    required this.homeCurrencyTotal,
  });

  final ExpenseGroupGranularity granularity;

  /// The start of this group's period (midnight of the day / the Monday of
  /// the week / the 1st of the month) — this group's stable identity (for
  /// collapse/expand state) and the input to its display label.
  final DateTime periodStart;

  /// This group's expenses, in whatever order they arrived in — the Spend
  /// tab's DAO already sorts newest-first; this function doesn't re-sort
  /// within a group.
  final List<Expense> expenses;

  final List<CurrencyAmount> perCurrencyTotals;

  /// Empty when no home currency is set — [homeCurrencyTotal] is then
  /// always null and callers fall back to [perCurrencyTotals].
  final String homeCurrency;

  /// This group's total in [homeCurrency] — null when [homeCurrency] is
  /// empty, OR when this group doesn't itself mix currencies (mirrors
  /// ExpenseSummaryCard's own rule: a single-currency total is already the
  /// exact answer, and a second "converted" line would just be redundant
  /// noise). [HomeTotal.pendingCount] reports how many of this group's
  /// expenses aren't converted into it yet.
  final HomeTotal? homeCurrencyTotal;
}

/// Buckets [expenses] into [ExpenseGroup]s at the granularity
/// [granularityFor] picks for [trip]. Groups are always ordered
/// newest-period-first, regardless of [expenses]' own order — only each
/// group's internal expense order follows [expenses]' order.
List<ExpenseGroup> groupExpenses(
  Trip trip,
  List<Expense> expenses,
  String homeCurrency,
) {
  if (expenses.isEmpty) return const [];
  final granularity = granularityFor(trip, expenses);
  final buckets = <DateTime, List<Expense>>{};
  for (final expense in expenses) {
    final key = _periodStart(expense.date, granularity);
    (buckets[key] ??= []).add(expense);
  }
  final orderedKeys = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final key in orderedKeys)
      ExpenseGroup(
        granularity: granularity,
        periodStart: key,
        expenses: buckets[key]!,
        perCurrencyTotals: totalsByCurrency(buckets[key]!),
        homeCurrency: homeCurrency,
        homeCurrencyTotal:
            homeCurrency.isEmpty || !usesMultipleCurrencies(buckets[key]!)
                ? null
                : homeTotal(buckets[key]!, homeCurrency),
      ),
  ];
}

DateTime _periodStart(DateTime date, ExpenseGroupGranularity granularity) {
  final day = _dateOnly(date);
  switch (granularity) {
    case ExpenseGroupGranularity.day:
      return day;
    case ExpenseGroupGranularity.week:
      return day.subtract(Duration(days: day.weekday - 1));
    case ExpenseGroupGranularity.month:
      return DateTime(day.year, day.month, 1);
  }
}
