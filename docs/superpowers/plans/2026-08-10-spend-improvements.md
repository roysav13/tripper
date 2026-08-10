# Spend feature improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix four independent usability gaps in the Spend tab: the add-expense
button requires scrolling to reach, the expense list has no date structure,
long lists can't be collapsed, and deleting an expense has no confirmation —
plus make group totals show a single home-currency figure by making the
app's home currency mandatory on first use.

**Architecture:** A new pure domain module buckets expenses into
day/week/month groups with per-group totals (no DB/schema change — derives
entirely from the existing `Expense.date` field). The Spend tab widget
becomes stateful to track which groups are expanded, gains a nested
`Scaffold` to scope a floating add-expense button to just this tab, and
gates that button on the app's home-currency setting being non-empty.

**Tech Stack:** Flutter/Dart, Riverpod, existing `intl` `DateFormat` for
labels, `flutter_test` widget tests with the existing `FakeExpenseRepository`
boundary mock.

## Global Constraints

(From `CLAUDE.md` and `docs/superpowers/specs/2026-08-10-spend-improvements-design.md` — every task below implicitly includes these.)

- No `Color(0xFF...)` outside `lib/core/theme/app_colors.dart` — use
  `context.colors.accent` / `.surface` / `.inkMuted` etc.
- No `DateTime.now()` in domain code.
- Every user-facing string goes through ARB
  (`lib/l10n/app_en.arb`) — English only.
- Tests land in the same commit as the feature. Widget tests mock at the
  repository boundary (`FakeExpenseRepository`). No Drift schema change in
  this plan, so no migration test is needed.
- Visual language: mono/uppercase for dates and metadata
  (`MonoText`/`SectionLabel`), hairline `PaperCard`, no ad-hoc styling.
- No network calls added by this plan — everything here is local
  (currency selection, grouping math) except the *existing*, unchanged
  exchange-rate backfill.

---

### Task 1: Adaptive grouping domain functions (TDD)

**Files:**
- Create: `lib/features/expenses/domain/expense_grouping.dart`
- Test: `test/unit/expenses/expense_grouping_test.dart`

**Interfaces:**
- Consumes: `Expense`, `CurrencyAmount`, `HomeTotal`, `totalsByCurrency`,
  `homeTotal`, `usesMultipleCurrencies` (all existing, from
  `lib/features/expenses/domain/expense.dart`); `Trip.lengthInDays`
  (existing, from `lib/features/trips/domain/trip.dart`).
- Produces: `ExpenseGroupGranularity` (enum: `day`, `week`, `month`),
  `ExpenseGroup` (class: `granularity`, `periodStart` (`DateTime`),
  `expenses` (`List<Expense>`), `perCurrencyTotals` (`List<CurrencyAmount>`),
  `homeCurrency` (`String`), `homeCurrencyTotal` (`HomeTotal?`)),
  `granularityFor(Trip, List<Expense>)`, `groupExpenses(Trip, List<Expense>,
  String homeCurrency)` — consumed by Task 3.

- [ ] **Step 1: Write the failing tests**

Create `test/unit/expenses/expense_grouping_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/expenses/domain/expense.dart';
import 'package:tripper/features/expenses/domain/expense_grouping.dart';
import 'package:tripper/features/trips/domain/trip.dart';

const _tripNoDates = Trip(id: 't1', name: 'Thailand', destinations: ['Krabi']);

Trip _tripSpanning(int days) => Trip(
      id: 't1',
      name: 'Thailand',
      destinations: ['Krabi'],
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 1).add(Duration(days: days - 1)),
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
      expect(granularityFor(_tripSpanning(21), []), ExpenseGroupGranularity.day);
    });

    test('trip spanning 22 to 90 days groups by week', () {
      expect(granularityFor(_tripSpanning(22), []), ExpenseGroupGranularity.week);
      expect(granularityFor(_tripSpanning(90), []), ExpenseGroupGranularity.week);
    });

    test('trip spanning more than 90 days groups by month', () {
      expect(granularityFor(_tripSpanning(91), []), ExpenseGroupGranularity.month);
    });

    test('falls back to the expense date spread when the trip has no dates',
        () {
      final shortSpread = [
        _expense(id: 'a', date: DateTime(2026, 3, 1)),
        _expense(id: 'b', date: DateTime(2026, 3, 5)),
      ];
      expect(
          granularityFor(_tripNoDates, shortSpread), ExpenseGroupGranularity.day);

      final longSpread = [
        _expense(id: 'a', date: DateTime(2026, 1, 1)),
        _expense(id: 'b', date: DateTime(2026, 6, 1)),
      ];
      expect(granularityFor(_tripNoDates, longSpread),
          ExpenseGroupGranularity.month);
    });

    test('no trip dates and no expenses defaults to day, does not crash', () {
      expect(granularityFor(_tripNoDates, []), ExpenseGroupGranularity.day);
    });
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
            id: 'a', date: DateTime(2026, 3, 1), amountMinor: 1000, currency: 'ILS'),
        _expense(
            id: 'b', date: DateTime(2026, 3, 1), amountMinor: 500, currency: 'USD'),
        _expense(
            id: 'c', date: DateTime(2026, 3, 2), amountMinor: 300, currency: 'ILS'),
      ];
      final groups = groupExpenses(_tripSpanning(5), expenses, '');
      final day2 = groups.firstWhere((g) => g.periodStart == DateTime(2026, 3, 2));
      expect(day2.perCurrencyTotals, [(currency: 'ILS', amountMinor: 300)]);
      final day1 = groups.firstWhere((g) => g.periodStart == DateTime(2026, 3, 1));
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
        "homeCurrencyTotal is null for a single-currency group even with a "
        "home currency set — matches ExpenseSummaryCard's own rule that a "
        "single-currency total needs no second, redundant 'converted' line",
        () {
      final groups = groupExpenses(
        _tripSpanning(5),
        [
          _expense(
              id: 'a', date: DateTime(2026, 3, 1), amountMinor: 1000, currency: 'ILS'),
          _expense(
              id: 'b', date: DateTime(2026, 3, 1), amountMinor: 500, currency: 'ILS'),
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
            id: 'a', date: DateTime(2026, 3, 1), amountMinor: 10000, currency: 'ILS'),
        _expense(
          id: 'b',
          date: DateTime(2026, 3, 1),
          amountMinor: 2700,
          currency: 'USD',
          convertedAmountMinor: 10000,
          convertedCurrency: 'ILS',
        ),
        _expense(
            id: 'c', date: DateTime(2026, 3, 1), amountMinor: 500, currency: 'EUR'),
      ];
      final group = groupExpenses(_tripSpanning(5), expenses, 'ILS').single;
      expect(group.homeCurrencyTotal!.amountMinor, 20000);
      expect(group.homeCurrencyTotal!.pendingCount, 1);
      expect(group.homeCurrency, 'ILS');
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/expenses/expense_grouping_test.dart`
Expected: FAIL — `package:tripper/features/expenses/domain/expense_grouping.dart` doesn't exist yet.

- [ ] **Step 3: Implement**

Create `lib/features/expenses/domain/expense_grouping.dart`:

```dart
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
  return latest.difference(earliest).inDays + 1;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/unit/expenses/expense_grouping_test.dart`
Expected: PASS, all cases.

- [ ] **Step 5: Run analyze**

Run: `flutter analyze lib/features/expenses/domain/expense_grouping.dart test/unit/expenses/expense_grouping_test.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/features/expenses/domain/expense_grouping.dart test/unit/expenses/expense_grouping_test.dart
git commit -m "feat(expenses): add adaptive day/week/month grouping domain functions"
```

---

### Task 2: Add-expense FAB + mandatory home-currency gate

**Files:**
- Modify: `lib/features/expenses/presentation/trip_expenses_tab.dart`
- Modify: `test/widget/expenses/trip_expenses_tab_test.dart`

**Interfaces:**
- Consumes: `showCurrencyPicker(BuildContext, {String? selected, bool
  allowNone})` (existing, `currency_picker.dart`); `homeCurrencyProvider`
  (existing `NotifierProvider<HomeCurrencyController, String>`,
  `lib/core/settings/settings_service.dart` — `.notifier.set(String)` to
  write it).
- Produces: no new public interface — this is the FAB + gate only. Task 3
  builds on top of this file's structure (nested `Scaffold` +
  `_addExpense`).

- [ ] **Step 1: Write the failing tests**

Add to `test/widget/expenses/trip_expenses_tab_test.dart` (inside `main()`,
alongside the existing tests — do not remove any existing test yet, this
task doesn't touch grouping):

```dart
  testWidgets('a floating add-expense button is shown when there are expenses',
      (tester) async {
    final repo = FakeExpenseRepository([_expense(id: 'a')]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets(
      'tapping the FAB with no home currency set asks for one before '
      'opening the expense form', (tester) async {
    final repo = FakeExpenseRepository([_expense(id: 'a')]);
    await tester.pumpWidget(await _app(repo)); // homeCurrency: '' (default)
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Add expense'), findsNothing);
    expect(find.text('Search currency'), findsOneWidget);

    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();

    expect(find.text('Add expense'), findsOneWidget);
  });

  testWidgets(
      'tapping the FAB with a home currency already set opens the form '
      'directly', (tester) async {
    final repo = FakeExpenseRepository([_expense(id: 'a')]);
    await tester.pumpWidget(await _app(repo, homeCurrency: 'ILS'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Add expense'), findsOneWidget);
  });

  testWidgets(
      'the empty-state CTA also asks for a home currency first when unset',
      (tester) async {
    await tester.pumpWidget(await _app(FakeExpenseRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add an expense'));
    await tester.pumpAndSettle();

    expect(find.text('Add expense'), findsNothing);
    expect(find.text('Search currency'), findsOneWidget);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widget/expenses/trip_expenses_tab_test.dart`
Expected: FAIL — no `FloatingActionButton` exists yet; tapping the CTA
opens the form directly instead of a currency picker.

- [ ] **Step 3: Implement**

Replace `lib/features/expenses/presentation/trip_expenses_tab.dart` in full:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/domain/trip.dart';
import '../domain/expense.dart';
import 'currency_picker.dart';
import 'expense_form_sheet.dart';
import 'expense_providers.dart';
import 'expense_widgets.dart';

/// Spend tab inside a trip's detail screen (M5.5).
class TripExpensesTab extends ConsumerWidget {
  const TripExpensesTab({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final asyncExpenses = ref.watch(tripExpensesProvider(trip.id));
    final expenses = asyncExpenses.valueOrNull ?? const <Expense>[];
    final summary = ref.watch(tripExpenseSummaryProvider(trip.id));

    if (asyncExpenses.hasError) {
      return ErrorState(
        onRetry: () => ref.invalidate(tripExpensesProvider(trip.id)),
      );
    }

    if (asyncExpenses.hasValue && expenses.isEmpty) {
      return EmptyState(
        icon: Icons.payments_outlined,
        title: l10n.expensesEmptyTitle,
        body: l10n.expensesEmptyBody,
        ctaLabel: l10n.expensesEmptyCta,
        onCta: () => _addExpense(
          context,
          ref,
          tripId: trip.id,
          defaultCurrency: summary.mainCurrency,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.expensesEmptyCta,
        backgroundColor: colors.accent,
        foregroundColor: colors.surface,
        onPressed: () => _addExpense(
          context,
          ref,
          tripId: trip.id,
          defaultCurrency: summary.mainCurrency,
        ),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        children: [
          ExpenseSummaryCard(
            totals: summary.totals,
            breakdown: summary.breakdown,
            home: summary.home,
            homeCurrency: summary.homeCurrency,
            showConversionOffHint:
                summary.homeCurrency.isEmpty && summary.totals.length > 1,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final expense in expenses)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
              child: ExpenseRowCard(
                expense: expense,
                onTap: () => showExpenseFormSheet(
                  context,
                  tripId: trip.id,
                  existing: expense,
                  defaultCurrency: summary.mainCurrency,
                ),
                onDelete: () => _delete(context, ref, expense),
              ),
            ),
        ],
      ),
    );
  }

  /// Both the FAB and the empty-state CTA route through here: a home
  /// currency is required before the first "add expense" attempt that
  /// finds one unset (group totals need a single currency to total into —
  /// see docs/superpowers/specs/2026-08-10-spend-improvements-design.md).
  /// Dismissing the picker cancels the whole add attempt; once set, this
  /// never interrupts again since homeCurrencyProvider is a single
  /// app-wide setting, not per-trip.
  Future<void> _addExpense(
    BuildContext context,
    WidgetRef ref, {
    required String tripId,
    String? defaultCurrency,
  }) async {
    final home = ref.read(homeCurrencyProvider);
    if (home.isEmpty) {
      final chosen = await showCurrencyPicker(context, allowNone: false);
      if (chosen == null) return;
      await ref.read(homeCurrencyProvider.notifier).set(chosen);
    }
    if (!context.mounted) return;
    showExpenseFormSheet(
      context,
      tripId: tripId,
      defaultCurrency: defaultCurrency,
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    // Resolve everything from ref/context BEFORE the await — the same
    // use-after-dispose class of bug that bit the vault link dialog.
    final repo = ref.read(expenseRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repo.deleteExpense(expense.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.expenseDeleted)));
  }
}
```

Note: the inline `OutlinedButton.icon` "+ Add expense" that used to sit at
the bottom of the list is gone — the FAB replaces it. `context.colors`
needs `import '../../../core/theme/app_colors.dart';` (new import, wasn't
needed before since colors weren't read directly in this file).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widget/expenses/trip_expenses_tab_test.dart`
Expected: PASS, all cases (existing + new).

- [ ] **Step 5: Run analyze**

Run: `flutter analyze lib/features/expenses/presentation/trip_expenses_tab.dart test/widget/expenses/trip_expenses_tab_test.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/features/expenses/presentation/trip_expenses_tab.dart test/widget/expenses/trip_expenses_tab_test.dart
git commit -m "feat(expenses): add floating add-expense button, gate it on a home currency"
```

---

### Task 3: Wire grouping + collapsible sections into the Spend tab

**Files:**
- Modify: `lib/features/expenses/presentation/trip_expenses_tab.dart`
- Modify: `lib/features/expenses/presentation/expense_widgets.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `test/widget/expenses/trip_expenses_tab_test.dart`

**Interfaces:**
- Consumes: `ExpenseGroup`, `ExpenseGroupGranularity`, `groupExpenses` (Task
  1, `lib/features/expenses/domain/expense_grouping.dart`); `formatMinor`,
  `minorDigitsFor` (existing, `lib/features/expenses/domain/currencies.dart`,
  already imported transitively via `expense_widgets.dart`).
- Produces: `ExpenseGroupHeader` widget (in `expense_widgets.dart`) — used
  only by `trip_expenses_tab.dart`, no other consumer.

**⚠️ Important — this task also edits three existing test assertions**,
because a new group header can legitimately duplicate a total the summary
card already shows (every existing fixture in this file uses expenses on
the same single date, which becomes one group whose total equals the whole
trip's total). This is expected, not a bug: both the summary card's total
and that one group's header total are correctly rendered at once. Step 1
below lists the exact three lines to change from `findsOneWidget` to
`findsWidgets`, alongside the new tests.

- [ ] **Step 1: Write the failing tests**

First, edit these three existing assertions in
`test/widget/expenses/trip_expenses_tab_test.dart`:

In `'total and category breakdown render with exact amounts'`, change:
```dart
    expect(find.text('320.00 ILS'), findsOneWidget);
```
to:
```dart
    // Also appears in the (single) group's own header, which mirrors the
    // page total for this single-group fixture.
    expect(find.text('320.00 ILS'), findsWidgets);
```

In `'with a home currency set, a converted expense shows its stored ≈
amount and contributes to a combined total'`, change:
```dart
    expect(find.text('≈ 200.00 ILS'), findsOneWidget); // combined total
```
to:
```dart
    // Also appears in the (single) group's own header, same reasoning.
    expect(find.text('≈ 200.00 ILS'), findsWidgets); // combined total
```

In `'an unconverted expense is reported as pending rather than dropped from
the combined total'`, change both:
```dart
    expect(find.text('≈ 100.00 ILS'), findsOneWidget);
    expect(find.text('1 expense not converted yet'), findsOneWidget);
```
to:
```dart
    expect(find.text('≈ 100.00 ILS'), findsWidgets);
    expect(find.text('1 expense not converted yet'), findsWidgets);
```

Now add these new tests to the same file's `main()`:

```dart
  testWidgets(
      'expenses spanning multiple days render one group header per day, '
      'newest first', (tester) async {
    final repo = FakeExpenseRepository([
      Expense(
          id: 'a',
          tripId: 't1',
          amountMinor: 1000,
          currency: 'ILS',
          category: ExpenseCategory.food,
          date: DateTime(2026, 8, 1),
          notes: 'Day1'),
      Expense(
          id: 'b',
          tripId: 't1',
          amountMinor: 2000,
          currency: 'ILS',
          category: ExpenseCategory.food,
          date: DateTime(2026, 8, 3),
          notes: 'Day3'),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    expect(find.text('SAT, AUG 1'), findsOneWidget);
    expect(find.text('MON, AUG 3'), findsOneWidget);
  });

  testWidgets(
      'only the newest group is expanded by default; tapping a header '
      'toggles it', (tester) async {
    final repo = FakeExpenseRepository([
      Expense(
          id: 'a',
          tripId: 't1',
          amountMinor: 1000,
          currency: 'ILS',
          category: ExpenseCategory.food,
          date: DateTime(2026, 8, 1),
          notes: 'OldDay'),
      Expense(
          id: 'b',
          tripId: 't1',
          amountMinor: 2000,
          currency: 'ILS',
          category: ExpenseCategory.food,
          date: DateTime(2026, 8, 3),
          notes: 'NewDay'),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    expect(find.text('NewDay'), findsOneWidget);
    expect(find.text('OldDay'), findsNothing);

    await tester.tap(find.text('SAT, AUG 1'));
    await tester.pumpAndSettle();
    expect(find.text('OldDay'), findsOneWidget);

    await tester.tap(find.text('MON, AUG 3'));
    await tester.pumpAndSettle();
    expect(find.text('NewDay'), findsNothing);
  });

  testWidgets(
      'each group totals only its own expenses in the home currency, not '
      'the trip-wide sum', (tester) async {
    final repo = FakeExpenseRepository([
      Expense(
          id: 'a1',
          tripId: 't1',
          amountMinor: 10000,
          currency: 'ILS',
          category: ExpenseCategory.food,
          date: DateTime(2026, 8, 1)),
      Expense(
          id: 'a2',
          tripId: 't1',
          amountMinor: 1000,
          currency: 'USD',
          category: ExpenseCategory.food,
          date: DateTime(2026, 8, 1),
          convertedAmountMinor: 5000,
          convertedCurrency: 'ILS'),
      Expense(
          id: 'b1',
          tripId: 't1',
          amountMinor: 3000,
          currency: 'ILS',
          category: ExpenseCategory.food,
          date: DateTime(2026, 8, 3)),
      Expense(
          id: 'b2',
          tripId: 't1',
          amountMinor: 400,
          currency: 'USD',
          category: ExpenseCategory.food,
          date: DateTime(2026, 8, 3),
          convertedAmountMinor: 2000,
          convertedCurrency: 'ILS'),
    ]);
    await tester.pumpWidget(await _app(repo, homeCurrency: 'ILS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SAT, AUG 1')); // expand the older group too
    await tester.pumpAndSettle();

    expect(find.text('≈ 150.00 ILS'), findsOneWidget); // Aug 1: 100 + 50
    expect(find.text('≈ 50.00 ILS'), findsOneWidget); // Aug 3: 30 + 20
    expect(find.text('≈ 200.00 ILS'), findsOneWidget); // trip-wide, summary card
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widget/expenses/trip_expenses_tab_test.dart`
Expected: FAIL — no group headers exist yet, all expenses render as one
flat list.

- [ ] **Step 3: Add the ARB string**

In `lib/l10n/app_en.arb`, add near the other `expenses*` keys (after
`expensesRatesAsOf`'s block):

```json
  "expenseGroupWeekOf": "Week of {date}",
  "@expenseGroupWeekOf": {
    "placeholders": { "date": { "type": "String" } }
  },
```

- [ ] **Step 4: Add `ExpenseGroupHeader` to `expense_widgets.dart`**

Add these imports to the top of `lib/features/expenses/presentation/expense_widgets.dart`:
```dart
import '../../../core/widgets/section_label.dart';
import '../domain/expense_grouping.dart';
```

Add this class at the end of the file (after `ExpenseRowCard`):

```dart
/// A collapsible group's header: the period's label, its total (home
/// currency when the group mixes currencies and one is set, otherwise one
/// line per currency — see [ExpenseGroup.homeCurrencyTotal]), and an
/// expand/collapse chevron. Tapping anywhere on the header toggles
/// [expanded].
class ExpenseGroupHeader extends StatelessWidget {
  const ExpenseGroupHeader({
    super.key,
    required this.group,
    required this.expanded,
    required this.onTap,
  });

  final ExpenseGroup group;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final pending = group.homeCurrencyTotal?.pendingCount ?? 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SectionLabel(_label(l10n, group))),
                MonoText(_totalText(group)),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: colors.inkMuted,
                ),
              ],
            ),
            if (pending > 0)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: MonoText(
                  l10n.expensesConversionPending(pending),
                  muted: true,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _label(AppLocalizations l10n, ExpenseGroup group) =>
      switch (group.granularity) {
        ExpenseGroupGranularity.day =>
          DateFormat('EEE, MMM d').format(group.periodStart),
        ExpenseGroupGranularity.week => l10n.expenseGroupWeekOf(
            DateFormat('MMM d').format(group.periodStart),
          ),
        ExpenseGroupGranularity.month =>
          DateFormat('MMMM yyyy').format(group.periodStart),
      };

  String _totalText(ExpenseGroup group) {
    final home = group.homeCurrencyTotal;
    if (home != null) {
      return '≈ ${formatMinor(home.amountMinor, digits: minorDigitsFor(group.homeCurrency))} '
          '${group.homeCurrency}';
    }
    return group.perCurrencyTotals
        .map((t) =>
            '${formatMinor(t.amountMinor, digits: minorDigitsFor(t.currency))} ${t.currency}')
        .join(' · ');
  }
}
```

- [ ] **Step 5: Wire it into the Spend tab**

Replace `lib/features/expenses/presentation/trip_expenses_tab.dart` in full:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/domain/trip.dart';
import '../domain/expense.dart';
import '../domain/expense_grouping.dart';
import 'currency_picker.dart';
import 'expense_form_sheet.dart';
import 'expense_providers.dart';
import 'expense_widgets.dart';

/// Spend tab inside a trip's detail screen (M5.5).
class TripExpensesTab extends ConsumerStatefulWidget {
  const TripExpensesTab({super.key, required this.trip});

  final Trip trip;

  @override
  ConsumerState<TripExpensesTab> createState() => _TripExpensesTabState();
}

class _TripExpensesTabState extends ConsumerState<TripExpensesTab> {
  /// Which groups (keyed by [ExpenseGroup.periodStart]) are expanded.
  /// Seeded once, on the first build that has groups, to contain only the
  /// newest group — collapse/expand after that is purely the user's own
  /// taps. In-memory only; resets on remount, same as every other
  /// transient UI toggle in this app.
  Set<DateTime>? _expandedGroups;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final asyncExpenses = ref.watch(tripExpensesProvider(widget.trip.id));
    final expenses = asyncExpenses.valueOrNull ?? const <Expense>[];
    final summary = ref.watch(tripExpenseSummaryProvider(widget.trip.id));

    if (asyncExpenses.hasError) {
      return ErrorState(
        onRetry: () => ref.invalidate(tripExpensesProvider(widget.trip.id)),
      );
    }

    if (asyncExpenses.hasValue && expenses.isEmpty) {
      return EmptyState(
        icon: Icons.payments_outlined,
        title: l10n.expensesEmptyTitle,
        body: l10n.expensesEmptyBody,
        ctaLabel: l10n.expensesEmptyCta,
        onCta: () => _addExpense(defaultCurrency: summary.mainCurrency),
      );
    }

    final groups = groupExpenses(widget.trip, expenses, summary.homeCurrency);
    _expandedGroups ??= groups.isEmpty ? {} : {groups.first.periodStart};

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.expensesEmptyCta,
        backgroundColor: colors.accent,
        foregroundColor: colors.surface,
        onPressed: () => _addExpense(defaultCurrency: summary.mainCurrency),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        children: [
          ExpenseSummaryCard(
            totals: summary.totals,
            breakdown: summary.breakdown,
            home: summary.home,
            homeCurrency: summary.homeCurrency,
            showConversionOffHint:
                summary.homeCurrency.isEmpty && summary.totals.length > 1,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final group in groups) ...[
            ExpenseGroupHeader(
              group: group,
              expanded: _expandedGroups!.contains(group.periodStart),
              onTap: () => setState(() {
                final isExpanded = _expandedGroups!.contains(group.periodStart);
                if (isExpanded) {
                  _expandedGroups!.remove(group.periodStart);
                } else {
                  _expandedGroups!.add(group.periodStart);
                }
              }),
            ),
            if (_expandedGroups!.contains(group.periodStart))
              for (final expense in group.expenses)
                Padding(
                  padding:
                      const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
                  child: ExpenseRowCard(
                    expense: expense,
                    onTap: () => showExpenseFormSheet(
                      context,
                      tripId: widget.trip.id,
                      existing: expense,
                      defaultCurrency: summary.mainCurrency,
                    ),
                    onDelete: () => _delete(expense),
                  ),
                ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }

  Future<void> _addExpense({String? defaultCurrency}) async {
    final home = ref.read(homeCurrencyProvider);
    if (home.isEmpty) {
      final chosen = await showCurrencyPicker(context, allowNone: false);
      if (chosen == null) return;
      await ref.read(homeCurrencyProvider.notifier).set(chosen);
    }
    if (!mounted) return;
    showExpenseFormSheet(
      context,
      tripId: widget.trip.id,
      defaultCurrency: defaultCurrency,
    );
  }

  Future<void> _delete(Expense expense) async {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.read(expenseRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repo.deleteExpense(expense.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.expenseDeleted)));
  }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/widget/expenses/trip_expenses_tab_test.dart`
Expected: PASS, all cases (existing, edited, and new).

- [ ] **Step 7: Run analyze**

Run: `flutter analyze lib/features/expenses/presentation/trip_expenses_tab.dart lib/features/expenses/presentation/expense_widgets.dart test/widget/expenses/trip_expenses_tab_test.dart`
Expected: No issues found.

- [ ] **Step 8: Regenerate localizations and commit**

```bash
flutter gen-l10n
git add lib/features/expenses/presentation/trip_expenses_tab.dart lib/features/expenses/presentation/expense_widgets.dart lib/l10n/app_en.arb lib/l10n/app_localizations*.dart test/widget/expenses/trip_expenses_tab_test.dart
git commit -m "feat(expenses): group the Spend list by day/week/month, collapsible"
```

---

### Task 4: Manual delete confirmation

**Files:**
- Modify: `lib/features/expenses/presentation/trip_expenses_tab.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `test/widget/expenses/trip_expenses_tab_test.dart`

**Interfaces:**
- Consumes: `l10n.cancel`, `l10n.menuDelete` (existing, already used by
  Place's identical confirmation pattern in `place_actions_sheet.dart`).
- Produces: no new public interface.

- [ ] **Step 1: Write the failing tests**

In `test/widget/expenses/trip_expenses_tab_test.dart`, replace the existing
test:

```dart
  testWidgets('deleting a row removes it and confirms via snackbar',
      (tester) async {
    final repo = FakeExpenseRepository([_expense(id: 'a', notes: 'Taxi')]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();
    expect(find.text('Taxi'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Taxi'), findsNothing);
    expect(find.text('Expense deleted.'), findsOneWidget);
  });
```

with:

```dart
  testWidgets('deleting a row asks for confirmation before removing it',
      (tester) async {
    final repo = FakeExpenseRepository([_expense(id: 'a', notes: 'Taxi')]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();
    expect(find.text('Taxi'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    // Still present until confirmed.
    expect(find.text('Taxi'), findsOneWidget);
    expect(find.text('Delete this expense?'), findsOneWidget);

    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Taxi'), findsNothing);
    expect(find.text('Expense deleted.'), findsOneWidget);
  });

  testWidgets('cancelling the delete confirmation keeps the expense',
      (tester) async {
    final repo = FakeExpenseRepository([_expense(id: 'a', notes: 'Taxi')]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Taxi'), findsOneWidget);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widget/expenses/trip_expenses_tab_test.dart`
Expected: FAIL — deletion still happens immediately, no confirmation dialog
appears.

- [ ] **Step 3: Add the ARB strings**

In `lib/l10n/app_en.arb`, add near `deletePlaceTitle`/`deletePlaceBody` (or
alongside the other `expense*` keys — either location is fine, group with
whichever reads more naturally):

```json
  "deleteExpenseTitle": "Delete this expense?",
  "deleteExpenseBody": "This removes it from the trip's total.",
```

- [ ] **Step 4: Implement**

In `lib/features/expenses/presentation/trip_expenses_tab.dart`, replace the
`_delete` method with:

```dart
  Future<void> _delete(Expense expense) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteExpenseTitle),
        content: Text(l10n.deleteExpenseBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.menuDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Resolve everything from ref/context BEFORE the next await — the same
    // use-after-dispose class of bug that bit the vault link dialog.
    final repo = ref.read(expenseRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repo.deleteExpense(expense.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.expenseDeleted)));
  }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/widget/expenses/trip_expenses_tab_test.dart`
Expected: PASS, all cases.

- [ ] **Step 6: Run the full existing expense test suite**

Run: `flutter test test/unit/expenses/ test/widget/expenses/`
Expected: PASS — confirms nothing in Tasks 1-4 regressed the pre-existing
`expenses_dao_test.dart`, `expense_conversion_service_test.dart`,
`expense_test.dart`, or `expenses_migration_test.dart`.

- [ ] **Step 7: Run analyze**

Run: `flutter analyze lib/features/expenses/ test/unit/expenses/ test/widget/expenses/`
Expected: No issues found.

- [ ] **Step 8: Regenerate localizations and commit**

```bash
flutter gen-l10n
git add lib/features/expenses/presentation/trip_expenses_tab.dart lib/l10n/app_en.arb lib/l10n/app_localizations*.dart test/widget/expenses/trip_expenses_tab_test.dart
git commit -m "feat(expenses): require confirmation before deleting an expense"
```

## Self-Review Notes

- **Spec coverage:** all five design points covered — FAB (Task 2),
  adaptive grouping (Task 1 domain + Task 3 wiring), collapsible groups
  defaulting to newest-expanded (Task 3), group totals in home currency
  with pending/legacy fallback (Task 1's `homeCurrencyTotal` +
  Task 3's `ExpenseGroupHeader`), mandatory home currency on first add
  (Task 2), manual delete confirmation (Task 4).
- **Refinement caught during planning, not left for the review loop:**
  `ExpenseGroup.homeCurrencyTotal` is null not just when `homeCurrency` is
  empty, but also when a group doesn't itself mix currencies — mirroring
  `ExpenseSummaryCard`'s existing `home` field rule exactly (only shown
  when the trip/group actually needs a combined figure). Missing this
  would have made every single-currency group show a redundant "≈" line
  next to its own already-exact total.
  **Also caught:** three pre-existing widget-test assertions
  (`findsOneWidget` on a total/pending string) had to change to
  `findsWidgets`, because every existing fixture in this test file uses a
  single date — under the new grouping, that single group's header total
  legitimately duplicates the page-level total. Verified by tracing each
  existing fixture's dates and currencies by hand rather than leaving it
  for a failing-test surprise mid-implementation. Task 3's Step 1 lists
  the exact three lines and why.
- **Placeholder scan:** no TBD/TODO; every step has complete, runnable
  code including exact ARB additions.
- **Type consistency:** `ExpenseGroup`/`ExpenseGroupGranularity`/
  `groupExpenses` (Task 1) are consumed with matching names and signatures
  in Task 3's `ExpenseGroupHeader` and `_TripExpensesTabState.build`.
  `_addExpense`/`_delete` signatures are introduced in Task 2 as
  `ConsumerWidget` instance methods taking `(context, ref, ...)`, then
  carried into Task 3's `ConsumerStatefulWidget` conversion with the
  simplified `State`-class signatures (`context`/`ref`/`mounted` available
  directly) — Task 4 modifies the Task-3 (stateful) version of `_delete`,
  not the Task-2 version.
- **Weekday-dependent test fixtures verified against a real calendar**
  (not assumed): Mar 2 2026 = Monday, Mar 9 2026 = Monday (next week), Aug
  1 2026 = Saturday, Aug 3 2026 = Monday — used consistently across Tasks
  1 and 3's test dates.
