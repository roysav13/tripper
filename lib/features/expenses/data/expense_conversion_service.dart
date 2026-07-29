import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/exchange_rates.dart';
import '../domain/expense.dart';
import '../presentation/expense_providers.dart';
import 'exchange_rate_service.dart';
import 'expense_repository.dart';

/// Fills in the stored home-currency conversion for any expense missing
/// one (M5.5b). Runs at app start, after adding an expense, and when the
/// home currency changes.
///
/// Everything about this is best-effort by design: no rates (offline,
/// endpoint down) simply leaves the expense unconverted until next time,
/// which is exactly the "keep it empty until the next connection"
/// behaviour asked for — and it satisfies hard rule 4, since the
/// underlying amounts stay fully readable regardless.
class ExpenseConversionService {
  ExpenseConversionService(this._repo, this._rates);

  final ExpenseRepository _repo;
  final ExchangeRateService _rates;

  /// Returns how many expenses were converted (0 when there was nothing
  /// to do *or* when rates were unavailable — the caller can't act on
  /// the difference, and both are non-events).
  Future<int> backfill(String homeCurrency) async {
    final home = homeCurrency.toUpperCase();
    final all = await _repo.getAll();
    final pending = needingConversion(all, home);
    if (kDebugMode) {
      debugPrint('[rates] backfill home=$home, ${all.length} expense(s), '
          '${pending.length} pending');
    }
    if (pending.isEmpty) return 0;

    final snapshot = await _rates.ratesFor(home);
    if (snapshot == null) {
      if (kDebugMode) {
        debugPrint('[rates] no rates available — ${pending.length} '
            'expense(s) stay pending until the next connection');
      }
      return 0;
    }
    if (kDebugMode) {
      debugPrint('[rates] got ${snapshot.rates.length} rates for '
          '${snapshot.base}, fetched ${snapshot.fetchedAt}');
    }

    var converted = 0;
    for (final expense in pending) {
      final amount = convertMinor(
        expense.amountMinor,
        expense.currency,
        home,
        snapshot,
      );
      // An unknown currency (typo, exotic code the endpoint omits) stays
      // pending forever rather than being silently zeroed — visible as a
      // "not converted" count in the UI.
      if (amount == null) {
        if (kDebugMode) {
          debugPrint('[rates] no rate for ${expense.currency} -> $home; '
              'expense stays unconverted');
        }
        continue;
      }
      await _repo.setConversion(
        expense.id,
        amountMinor: amount,
        currency: home,
        rateAt: snapshot.fetchedAt,
      );
      converted++;
    }
    if (kDebugMode) debugPrint('[rates] converted $converted expense(s)');
    return converted;
  }

  /// Clears conversions that point at a currency other than [newHome] so
  /// the next backfill recomputes them. Called on a home-currency change
  /// — keeping the old figures would mean a total mixing two "home"
  /// currencies, which is the original bug wearing a different hat.
  Future<void> clearStaleConversions(String newHome) async {
    final home = newHome.toUpperCase();
    for (final expense in await _repo.getAll()) {
      if (expense.convertedCurrency != null &&
          expense.convertedCurrency != home) {
        await _repo.setConversion(
          expense.id,
          amountMinor: null,
          currency: null,
          rateAt: null,
        );
      }
    }
  }
}

final expenseConversionServiceProvider = Provider<ExpenseConversionService>(
  (ref) => ExpenseConversionService(
    ref.watch(expenseRepositoryProvider),
    ref.watch(exchangeRateServiceProvider),
  ),
);
