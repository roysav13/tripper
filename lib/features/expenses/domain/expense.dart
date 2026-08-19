import 'package:flutter/foundation.dart';

/// Order is stable — stored as index in the DB. Append only.
enum ExpenseCategory {
  transport,
  stay,
  food,
  activities,
  shopping,
  other,
}

@immutable
class Expense {
  const Expense({
    required this.id,
    required this.tripId,
    required this.amountMinor,
    required this.currency,
    required this.category,
    required this.date,
    this.notes = '',
    this.convertedAmountMinor,
    this.convertedCurrency,
    this.convertedRateAt,
  });

  final String id;
  final String tripId;

  /// Minor units (see the Expenses table) — integer arithmetic only.
  final int amountMinor;
  final String currency;
  final ExpenseCategory category;
  final DateTime date;
  final String notes;

  /// Home-currency conversion, stored once rates were available (M5.5b).
  /// Null when this expense hasn't been converted yet — added offline,
  /// or the home currency changed since. Null is "pending", not "zero".
  final int? convertedAmountMinor;
  final String? convertedCurrency;
  final DateTime? convertedRateAt;

  bool get isConverted =>
      convertedAmountMinor != null && convertedCurrency != null;

  /// True when this expense already counts toward a [homeCurrency] total
  /// — either it's already in that currency, or it carries a conversion
  /// into it. A stale conversion into some *other* home currency doesn't
  /// count, which is what makes changing the setting re-backfill.
  bool countsToward(String homeCurrency) =>
      currency == homeCurrency || convertedCurrency == homeCurrency;

  /// This expense's value in [homeCurrency], or null if not available.
  int? valueIn(String homeCurrency) {
    if (currency == homeCurrency) return amountMinor;
    if (convertedCurrency == homeCurrency) return convertedAmountMinor;
    return null;
  }

  Expense copyWith({
    int? amountMinor,
    String? currency,
    ExpenseCategory? category,
    DateTime? date,
    String? notes,
    int? Function()? convertedAmountMinor,
    String? Function()? convertedCurrency,
    DateTime? Function()? convertedRateAt,
  }) {
    return Expense(
      id: id,
      tripId: tripId,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      convertedAmountMinor: convertedAmountMinor == null
          ? this.convertedAmountMinor
          : convertedAmountMinor(),
      convertedCurrency: convertedCurrency == null
          ? this.convertedCurrency
          : convertedCurrency(),
      convertedRateAt:
          convertedRateAt == null ? this.convertedRateAt : convertedRateAt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Expense &&
      other.id == id &&
      other.tripId == tripId &&
      other.amountMinor == amountMinor &&
      other.currency == currency &&
      other.category == category &&
      other.date == date &&
      other.notes == notes &&
      other.convertedAmountMinor == convertedAmountMinor &&
      other.convertedCurrency == convertedCurrency &&
      other.convertedRateAt == convertedRateAt;

  @override
  int get hashCode => Object.hash(
        id,
        tripId,
        amountMinor,
        currency,
        category,
        date,
        notes,
        convertedAmountMinor,
        convertedCurrency,
        convertedRateAt,
      );
}

/// One currency's subtotal.
typedef CurrencyAmount = ({String currency, int amountMinor});

/// Total in minor units for a **single currency's** expenses. Integer
/// sum — exact, no float drift. Callers must filter by currency first;
/// [totalsByCurrency] is what the UI actually uses.
int totalMinor(List<Expense> expenses) =>
    expenses.fold(0, (sum, e) => sum + e.amountMinor);

/// Totals grouped by currency — never summed across currencies.
///
/// v1 has no conversion (SPEC §3.2.1: no live rates), and a trip really
/// can mix currencies (₪ in Tel Aviv, $ on arrival). Adding 100 ILS to
/// 50 USD and calling it 150 of anything is simply wrong, so mixed trips
/// show one line per currency instead of one fabricated number.
///
/// Ordered by expense count desc (the trip's "main" currency first),
/// then by code — deliberately NOT by amount, since comparing amounts
/// across currencies is exactly the meaningless operation this fixes.
List<CurrencyAmount> totalsByCurrency(List<Expense> expenses) {
  final totals = <String, int>{};
  final counts = <String, int>{};
  for (final e in expenses) {
    totals[e.currency] = (totals[e.currency] ?? 0) + e.amountMinor;
    counts[e.currency] = (counts[e.currency] ?? 0) + 1;
  }
  final rows = [
    for (final entry in totals.entries)
      (currency: entry.key, amountMinor: entry.value),
  ];
  rows.sort((a, b) {
    final byCount = counts[b.currency]!.compareTo(counts[a.currency]!);
    return byCount != 0 ? byCount : a.currency.compareTo(b.currency);
  });
  return rows;
}

/// Per-category totals, each broken down by currency.
typedef CategoryTotals = ({
  ExpenseCategory category,
  List<CurrencyAmount> amounts,
});

/// Zero-spend categories omitted. Ordering: biggest-first while the trip
/// uses a single currency (the useful view), but stable enum order once
/// it's mixed — ranking "100 ILS" against "50 USD" would require rates
/// this app deliberately doesn't have.
List<CategoryTotals> categoryBreakdown(List<Expense> expenses) {
  final byCategory = <ExpenseCategory, List<Expense>>{};
  for (final e in expenses) {
    (byCategory[e.category] ??= []).add(e);
  }
  final rows = [
    for (final entry in byCategory.entries)
      (category: entry.key, amounts: totalsByCurrency(entry.value)),
  ];
  final multi = usesMultipleCurrencies(expenses);
  rows.sort((a, b) {
    if (multi) return a.category.index.compareTo(b.category.index);
    final aTotal = a.amounts.isEmpty ? 0 : a.amounts.first.amountMinor;
    final bTotal = b.amounts.isEmpty ? 0 : b.amounts.first.amountMinor;
    return bTotal.compareTo(aTotal);
  });
  return rows;
}

bool usesMultipleCurrencies(List<Expense> expenses) =>
    expenses.map((e) => e.currency).toSet().length > 1;

/// A single combined figure in the home currency, plus how many
/// expenses couldn't be included yet.
typedef HomeTotal = ({int amountMinor, int pendingCount, DateTime? ratesAt});

/// Sums every expense that already has a value in [homeCurrency] —
/// either natively or via its stored conversion — and counts the rest as
/// [pendingCount] rather than dropping them silently. A total that
/// quietly omits three expenses is exactly the class of bug that made
/// mixed-currency summing wrong in the first place, so the UI shows the
/// pending count next to the figure.
HomeTotal homeTotal(List<Expense> expenses, String homeCurrency) {
  var sum = 0;
  var pending = 0;
  DateTime? oldestRate;
  for (final e in expenses) {
    final value = e.valueIn(homeCurrency);
    if (value == null) {
      pending++;
      continue;
    }
    sum += value;
    final rateAt = e.convertedRateAt;
    if (rateAt != null && (oldestRate == null || rateAt.isBefore(oldestRate))) {
      oldestRate = rateAt;
    }
  }
  return (amountMinor: sum, pendingCount: pending, ratesAt: oldestRate);
}

/// A single headline figure for a set of expenses — what the Spend tab's
/// hero card leads with. The same three-way rule the old summary card
/// used inline, now reusable for both the trip-wide total and the
/// "today" stat: the one currency's total when there's only one, the
/// home-currency combined total when the set mixes currencies and a home
/// currency is set, or nothing (callers fall back to [perCurrency]) when
/// it mixes currencies with conversion off. [amountMinor]/[currency] are
/// null exactly in that last, ambiguous case — never a fabricated sum.
typedef HeadlineTotal = ({
  int? amountMinor,
  String? currency,
  bool isHomeConversion,
  int pendingCount,
  DateTime? ratesAt,
  List<CurrencyAmount> perCurrency,
});

HeadlineTotal headlineTotal(List<Expense> expenses, String homeCurrency) {
  final perCurrency = totalsByCurrency(expenses);
  if (perCurrency.length == 1) {
    final only = perCurrency.first;
    return (
      amountMinor: only.amountMinor,
      currency: only.currency,
      isHomeConversion: false,
      pendingCount: 0,
      ratesAt: null,
      perCurrency: perCurrency,
    );
  }
  if (perCurrency.length > 1 && homeCurrency.isNotEmpty) {
    final home = homeTotal(expenses, homeCurrency);
    return (
      amountMinor: home.amountMinor,
      currency: homeCurrency,
      isHomeConversion: true,
      pendingCount: home.pendingCount,
      ratesAt: home.ratesAt,
      perCurrency: perCurrency,
    );
  }
  return (
    amountMinor: null,
    currency: null,
    isHomeConversion: false,
    pendingCount: 0,
    ratesAt: null,
    perCurrency: perCurrency,
  );
}

/// Expenses still needing conversion into [homeCurrency] — the backfill
/// work list.
List<Expense> needingConversion(List<Expense> expenses, String homeCurrency) =>
    [
      for (final e in expenses)
        if (!e.countsToward(homeCurrency)) e,
    ];

/// The trip's main currency — the one used by the most expenses — which
/// is what the add-expense form pre-fills. Null when there are no
/// expenses yet, so the form asks rather than assuming.
String? tripCurrency(List<Expense> expenses) {
  final totals = totalsByCurrency(expenses);
  return totals.isEmpty ? null : totals.first.currency;
}

/// Parses user input ("12.30", "12,30", "12") into minor units. Returns
/// null for anything unparseable or negative — the form shows a
/// validation error rather than silently storing a wrong number.
///
/// [digits] is the currency's decimal count (see [Currency.minorDigits]);
/// with 0 (JPY, KRW, VND) "1000" means 1000 minor units, and a typed
/// decimal is rejected rather than quietly truncated.
int? parseAmountToMinor(String input, {int digits = 2}) {
  final cleaned = input.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  if (digits == 0) {
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) return null;
    return int.tryParse(cleaned);
  }
  if (!RegExp('^\\d+(\\.\\d{0,$digits})?\$').hasMatch(cleaned)) return null;
  final parts = cleaned.split('.');
  final major = int.tryParse(parts[0]);
  if (major == null) return null;
  final fraction =
      parts.length > 1 ? parts[1].padRight(digits, '0') : '0' * digits;
  final minor = int.tryParse(fraction);
  if (minor == null) return null;
  return major * _pow10(digits) + minor;
}

/// "1230" -> "12.30" (or "1230" for a 0-decimal currency). Fixed decimal
/// count so columns align in the mono numerals the design system uses.
String formatMinor(int amountMinor, {int digits = 2}) {
  if (digits == 0) return amountMinor.toString();
  final scale = _pow10(digits);
  final major = amountMinor ~/ scale;
  final minor = (amountMinor % scale).toString().padLeft(digits, '0');
  return '$major.$minor';
}

int _pow10(int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}
