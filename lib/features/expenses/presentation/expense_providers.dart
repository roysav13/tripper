import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/settings/settings_service.dart';
import '../data/expense_conversion_service.dart';
import '../data/expense_repository.dart';
import '../data/expenses_dao.dart';
import '../domain/expense.dart';

const _uuid = Uuid();

final expensesDaoProvider =
    Provider<ExpensesDao>((ref) => ref.watch(databaseProvider).expensesDao);

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => DriftExpenseRepository(
    ref.watch(expensesDaoProvider),
    ref.watch(clockProvider),
    _uuid.v4,
  ),
);

final tripExpensesProvider = StreamProvider.family<List<Expense>, String>(
  (ref, tripId) => ref.watch(expenseRepositoryProvider).watchForTrip(tripId),
);

/// Every trip's expenses — the conversion backfill's trigger and work
/// source (conversion is global, not per-trip).
final allExpensesProvider = StreamProvider<List<Expense>>(
  (ref) => ref.watch(expenseRepositoryProvider).watchAll(),
);

/// Totals + breakdown for a trip, derived from the stream above — pure
/// functions in the domain layer, no extra queries.
///
/// [totals] is per-currency and never summed across currencies (a trip
/// can legitimately mix ILS and USD, and v1 has no conversion rates);
/// [mainCurrency] is just what the add-expense form pre-fills. [headline]
/// and [todayHeadline] feed the Spend tab's hero card; "today" is scoped
/// via [clockProvider] here (not `DateTime.now()` in the domain layer).
final tripExpenseSummaryProvider = Provider.family<
    ({
      List<CurrencyAmount> totals,
      String? mainCurrency,
      List<CategoryTotals> breakdown,
      String homeCurrency,
      HeadlineTotal headline,
      HeadlineTotal todayHeadline,
    }),
    String>((ref, tripId) {
  final expenses =
      ref.watch(tripExpensesProvider(tripId)).valueOrNull ?? const <Expense>[];
  final homeCurrency = ref.watch(homeCurrencyProvider);
  final now = ref.watch(clockProvider)();
  final todaysExpenses = [
    for (final e in expenses)
      if (_isSameDay(e.date, now)) e,
  ];
  return (
    totals: totalsByCurrency(expenses),
    mainCurrency: tripCurrency(expenses),
    breakdown: categoryBreakdown(expenses),
    homeCurrency: homeCurrency,
    headline: headlineTotal(expenses, homeCurrency),
    todayHeadline: headlineTotal(todaysExpenses, homeCurrency),
  );
});

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Keeps stored conversions up to date: backfills on startup, whenever
/// expenses change (a new one arrives unconverted), and re-derives them
/// all when the home currency changes. Read once from `app.dart`.
final expenseConversionWiringProvider = Provider<void>((ref) {
  var running = false;

  Future<void> backfill() async {
    final home = ref.read(homeCurrencyProvider);
    if (home.isEmpty) {
      if (kDebugMode) {
        debugPrint('[rates] no home currency set — conversion is off');
      }
      return;
    }
    if (running) return;
    // Writing conversions re-fires the watch that triggered this, so a
    // re-entrancy guard is what stops an endless backfill loop.
    running = true;
    try {
      await ref.read(expenseConversionServiceProvider).backfill(home);
    } catch (_) {
      // Best-effort: conversion never blocks anything.
    } finally {
      running = false;
    }
  }

  // Any expense change (including one added while offline, once the
  // stream re-emits) re-attempts conversion.
  ref.listen(allExpensesProvider, (_, __) => backfill());

  ref.listen(homeCurrencyProvider, (previous, next) async {
    if (previous == next) return;
    try {
      if (next.isNotEmpty) {
        await ref
            .read(expenseConversionServiceProvider)
            .clearStaleConversions(next);
      }
    } catch (_) {}
    await backfill();
  });

  unawaited(backfill());
});
