import 'package:flutter/foundation.dart';

import 'currencies.dart';
import 'expense.dart';

/// A snapshot of conversion rates, all expressed against [base].
/// `rates['USD'] == 3.7` with `base == 'ILS'` means 1 ILS = 3.7 USD.
@immutable
class ExchangeRateSnapshot {
  const ExchangeRateSnapshot({
    required this.base,
    required this.rates,
    required this.fetchedAt,
  });

  final String base;
  final Map<String, double> rates;

  /// Surfaced in the UI ("rates from 23 Jul") — a converted figure whose
  /// age is hidden is a converted figure you can't sanity-check.
  final DateTime fetchedAt;

  /// Rate to convert [from] into [to], or null when either leg is
  /// missing (unknown currency, partial API response). Null propagates
  /// all the way to "no approximate total shown" rather than a guess.
  double? rateFor(String from, String to) {
    if (from == to) return 1;
    final fromRate = from == base ? 1.0 : rates[from];
    final toRate = to == base ? 1.0 : rates[to];
    if (fromRate == null || toRate == null) return null;
    if (fromRate == 0) return null;
    return toRate / fromRate;
  }

  bool isStale(DateTime now, Duration maxAge) =>
      now.difference(fetchedAt) > maxAge;
}

/// Converts one amount between currencies, **in minor units**.
///
/// Minor units are not a common scale: ¥1000 is 1000 minor units (JPY
/// has no decimals) while ₪10.00 is 1000 minor units. Multiplying by the
/// rate alone would therefore be wrong by 100× whenever the two
/// currencies differ in decimal places, so the result is rescaled by
/// `10^(toDigits - fromDigits)`.
///
/// Rounds half-away-from-zero — the result is already an approximation,
/// so the rule only needs to be predictable and documented.
int? convertMinor(
  int amountMinor,
  String from,
  String to,
  ExchangeRateSnapshot rates,
) {
  final rate = rates.rateFor(from, to);
  if (rate == null) return null;
  final fromDigits = minorDigitsFor(from);
  final toDigits = minorDigitsFor(to);
  final scale = _pow10(toDigits) / _pow10(fromDigits);
  return (amountMinor * rate * scale).round();
}

double _pow10(int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}

/// Sums per-currency totals into [target]. Returns null if **any** line
/// can't be converted — a partial total silently missing one currency
/// would be worse than showing none, which is the whole lesson of the
/// mixed-currency bug this feature exists to fix.
int? convertedTotalMinor(
  List<CurrencyAmount> totals,
  String target,
  ExchangeRateSnapshot rates,
) {
  var sum = 0;
  for (final total in totals) {
    final converted =
        convertMinor(total.amountMinor, total.currency, target, rates);
    if (converted == null) return null;
    sum += converted;
  }
  return sum;
}
