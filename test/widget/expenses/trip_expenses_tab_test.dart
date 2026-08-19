import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/expenses/domain/expense.dart';
import 'package:tripper/features/expenses/presentation/expense_providers.dart';
import 'package:tripper/features/expenses/presentation/trip_expenses_tab.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_expense_repository.dart';
import '../../helpers/test_preferences.dart';

final _today = DateTime(2026, 8, 5);

const _trip = Trip(id: 't1', name: 'Thailand', destinations: ['Krabi']);

Expense _expense({
  required String id,
  int amountMinor = 1000,
  ExpenseCategory category = ExpenseCategory.food,
  String notes = '',
  String tripId = 't1',
  String currency = 'ILS',
}) =>
    Expense(
      id: id,
      tripId: tripId,
      amountMinor: amountMinor,
      currency: currency,
      category: category,
      date: DateTime(2026, 8, 2),
      notes: notes,
    );

Future<Widget> _app(
  FakeExpenseRepository repo, {
  String homeCurrency = '',
}) async =>
    ProviderScope(
      overrides: [
        // The summary reads the home-currency setting (M5.5b), so prefs
        // must exist even for tests that don't care about conversion.
        await testPreferencesOverride(
          homeCurrency.isEmpty ? const {} : {'home_currency': homeCurrency},
        ),
        expenseRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => _today),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: TripExpensesTab(trip: _trip)),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

void main() {
  testWidgets('empty trip shows the designed empty state', (tester) async {
    await tester.pumpWidget(await _app(FakeExpenseRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Track what this trip costs'), findsOneWidget);
    // Design spec: the FAB only appears once there's something to add to —
    // the empty state has its own CTA instead.
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('the hero card totals every expense, exactly', (tester) async {
    final repo = FakeExpenseRepository([
      _expense(id: 'a', amountMinor: 1250, category: ExpenseCategory.food),
      _expense(id: 'b', amountMinor: 30000, category: ExpenseCategory.stay),
      _expense(id: 'c', amountMinor: 750, category: ExpenseCategory.food),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    // Total: 12.50 + 300.00 + 7.50 = 320.00
    // Also appears in the (single) group's own header, which mirrors the
    // page total for this single-group fixture.
    expect(find.text('320.00 ILS'), findsWidgets);
  });

  testWidgets(
      'the hero card shows no spend today when nothing landed on the '
      'clock-provided date', (tester) async {
    final repo = FakeExpenseRepository([
      _expense(id: 'a', amountMinor: 1250), // dated Aug 2, not "today"
      _expense(id: 'b', amountMinor: 750),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    expect(find.text('No spend yet'), findsOneWidget);
  });

  testWidgets("the hero card's today figure sums only today's expenses",
      (tester) async {
    final repo = FakeExpenseRepository([
      _expense(id: 'old', amountMinor: 1000), // Aug 2
      Expense(
        id: 'today1',
        tripId: 't1',
        amountMinor: 450,
        currency: 'ILS',
        category: ExpenseCategory.food,
        date: _today,
      ),
      Expense(
        id: 'today2',
        tripId: 't1',
        amountMinor: 100,
        currency: 'ILS',
        category: ExpenseCategory.food,
        date: _today,
      ),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    // Also matches today's own group header, which totals the same two
    // expenses — an expected duplicate, same reasoning as the grouping
    // tests below.
    expect(find.text('5.50 ILS'), findsNWidgets(2)); // today: 4.50 + 1.00
  });

  testWidgets(
      'a mixed-currency trip shows one total per currency and never a '
      'combined sum (reported bug: ILS + USD were added together)',
      (tester) async {
    final repo = FakeExpenseRepository([
      _expense(id: 'a', amountMinor: 10000, currency: 'ILS'),
      _expense(id: 'b', amountMinor: 5000, currency: 'USD'),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    expect(find.text('100.00 ILS'), findsWidgets);
    expect(find.text('50.00 USD'), findsWidgets);
    // 100 + 50 must never appear as a single figure in any currency.
    expect(find.textContaining('150.00'), findsNothing);
  });

  testWidgets(
      'with a home currency set, a converted expense shows its stored '
      '≈ amount and contributes to a combined total', (tester) async {
    final repo = FakeExpenseRepository([
      _expense(id: 'a', amountMinor: 10000, currency: 'ILS'),
      // 27.00 USD already converted to 100.00 ILS.
      Expense(
        id: 'b',
        tripId: 't1',
        amountMinor: 2700,
        currency: 'USD',
        category: ExpenseCategory.food,
        date: DateTime(2026, 8, 2),
        convertedAmountMinor: 10000,
        convertedCurrency: 'ILS',
      ),
    ]);
    await tester.pumpWidget(await _app(repo, homeCurrency: 'ILS'));
    await tester.pumpAndSettle();

    expect(find.text('≈ 100.00 ILS'), findsOneWidget); // the row
    // Also appears in the (single) group's own header, same reasoning.
    expect(find.text('≈ 200.00 ILS'), findsWidgets); // combined total
    expect(find.textContaining('not converted yet'), findsNothing);
  });

  testWidgets(
      'an unconverted expense is reported as pending rather than dropped '
      'from the combined total', (tester) async {
    final repo = FakeExpenseRepository([
      _expense(id: 'a', amountMinor: 10000, currency: 'ILS'),
      _expense(id: 'b', amountMinor: 2700, currency: 'USD'), // no conversion
    ]);
    await tester.pumpWidget(await _app(repo, homeCurrency: 'ILS'));
    await tester.pumpAndSettle();

    expect(find.text('≈ 100.00 ILS'), findsWidgets);
    expect(find.text('1 expense not converted yet'), findsWidgets);
  });

  testWidgets('every expense row shows its own currency code', (tester) async {
    final repo = FakeExpenseRepository([
      _expense(id: 'a', amountMinor: 10000, currency: 'ILS', notes: 'Taxi'),
      _expense(id: 'b', amountMinor: 5000, currency: 'USD', notes: 'Coffee'),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    expect(find.text('100.00 ILS'), findsWidgets);
    expect(find.text('50.00 USD'), findsWidgets);
  });

  testWidgets('a row shows its note, or the category when there is none',
      (tester) async {
    final repo = FakeExpenseRepository([
      _expense(id: 'a', notes: 'Longtail boat'),
      _expense(id: 'b', category: ExpenseCategory.shopping),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Longtail boat'), findsOneWidget);
    expect(find.text('Shopping'), findsWidgets);
  });

  testWidgets('only this trip\'s expenses appear', (tester) async {
    final repo = FakeExpenseRepository([
      _expense(id: 'mine', notes: 'Mine'),
      _expense(id: 'other', tripId: 'other-trip', notes: 'Not mine'),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Mine'), findsOneWidget);
    expect(find.text('Not mine'), findsNothing);
  });

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

  testWidgets('a stream failure shows the error state with retry',
      (tester) async {
    final repo = FakeExpenseRepository([_expense(id: 'a')]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    repo.emitError(Exception('boom'));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('many expenses render without overflow or exceptions',
      (tester) async {
    final repo = FakeExpenseRepository([
      for (var i = 0; i < 150; i++)
        _expense(
          id: 'e$i',
          amountMinor: 100 + i,
          notes: 'Expense number $i with a reasonably long note attached',
          category: ExpenseCategory.values[i % ExpenseCategory.values.length],
        ),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -2000),
      1000,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

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
        notes: 'Day1',
      ),
      Expense(
        id: 'b',
        tripId: 't1',
        amountMinor: 2000,
        currency: 'ILS',
        category: ExpenseCategory.food,
        date: DateTime(2026, 8, 3),
        notes: 'Day3',
      ),
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
        notes: 'OldDay',
      ),
      Expense(
        id: 'b',
        tripId: 't1',
        amountMinor: 2000,
        currency: 'ILS',
        category: ExpenseCategory.food,
        date: DateTime(2026, 8, 3),
        notes: 'NewDay',
      ),
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
        date: DateTime(2026, 8, 1),
      ),
      Expense(
        id: 'a2',
        tripId: 't1',
        amountMinor: 1000,
        currency: 'USD',
        category: ExpenseCategory.food,
        date: DateTime(2026, 8, 1),
        convertedAmountMinor: 5000,
        convertedCurrency: 'ILS',
      ),
      Expense(
        id: 'b1',
        tripId: 't1',
        amountMinor: 3000,
        currency: 'ILS',
        category: ExpenseCategory.food,
        date: DateTime(2026, 8, 3),
      ),
      Expense(
        id: 'b2',
        tripId: 't1',
        amountMinor: 400,
        currency: 'USD',
        category: ExpenseCategory.food,
        date: DateTime(2026, 8, 3),
        convertedAmountMinor: 2000,
        convertedCurrency: 'ILS',
      ),
    ]);
    await tester.pumpWidget(await _app(repo, homeCurrency: 'ILS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SAT, AUG 1')); // expand the older group too
    await tester.pumpAndSettle();

    expect(find.text('≈ 150.00 ILS'), findsOneWidget); // Aug 1: 100 + 50
    // Also appears on expense a2's own row (10.00 USD -> 50.00 ILS) now
    // that Aug 1 is expanded too — a coincidental match between that
    // unrelated row's converted amount and this group's total, same
    // "expected duplicate" reasoning as Step 1's edited assertions.
    expect(find.text('≈ 50.00 ILS'), findsWidgets); // Aug 3: 30 + 20
    expect(
      find.text('≈ 200.00 ILS'),
      findsOneWidget,
    ); // trip-wide, summary card
  });

  testWidgets('a week-granularity group header renders its label',
      (tester) async {
    // _trip has no start/end dates, so granularity falls back to the
    // expense date spread: these two dates are ~32 days apart, landing in
    // the week-granularity range (22-90 days). No existing test at the
    // widget level exercised week (or month) grouping, so the
    // expenseGroupWeekOf ARB string shipped with zero rendering coverage.
    final repo = FakeExpenseRepository([
      Expense(
        id: 'a',
        tripId: 't1',
        amountMinor: 1000,
        currency: 'ILS',
        category: ExpenseCategory.food,
        date: DateTime(2026, 7, 1),
      ),
      Expense(
        id: 'b',
        tripId: 't1',
        amountMinor: 2000,
        currency: 'ILS',
        category: ExpenseCategory.food,
        date: DateTime(2026, 8, 1),
      ),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    // Not hand-computing the exact Monday date — just proving the label
    // renders at all (SectionLabel upper-cases it: "WEEK OF ...").
    expect(find.textContaining('WEEK OF'), findsWidgets);
  });

  testWidgets(
      'a new expense added via the FAB is visible immediately, with no '
      'manual expand/collapse — regression test for the final-review '
      'finding that _expandedGroups only ever seeded once, so a newly '
      'appeared group (a new expense on a new day) rendered collapsed',
      (tester) async {
    final repo = FakeExpenseRepository([
      Expense(
        id: 'old',
        tripId: 't1',
        amountMinor: 1000,
        currency: 'ILS',
        category: ExpenseCategory.food,
        date: DateTime(2026, 8, 1), // an older day than "today"
        notes: 'OldDay',
      ),
    ]);
    // Home currency pre-set so the FAB opens the form directly, and
    // matches the only expense's currency so the form's currency field
    // (pre-filled from summary.mainCurrency) needs no picker interaction.
    await tester.pumpWidget(await _app(repo, homeCurrency: 'ILS'));
    await tester.pumpAndSettle();

    // Only one group exists so far, so it's expanded by default.
    expect(find.text('OldDay'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Add expense'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '25');
    await tester.enterText(
      find.widgetWithText(TextField, 'Note (optional)'),
      'NewToday',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The new expense lands on "today" (the fixed clock, Aug 5) — a group
    // that didn't exist in any previous build. It must render expanded
    // immediately: no tap on any group header.
    expect(find.text('NewToday'), findsOneWidget);
  });

  testWidgets(
      'selecting a category pill narrows the list and its group total to '
      'that category', (tester) async {
    final repo = FakeExpenseRepository([
      _expense(
        id: 'a',
        amountMinor: 1250,
        category: ExpenseCategory.food,
        notes: 'Coffee',
      ),
      _expense(
        id: 'b',
        amountMinor: 30000,
        category: ExpenseCategory.stay,
        notes: 'Hotel',
      ),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Hotel'), findsOneWidget);
    // Unfiltered ("All"), the group header totals both.
    // 12.50 + 300.00 = 312.50.
    expect(find.text('312.50 ILS'), findsWidgets);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();

    expect(find.text('Coffee'), findsNothing);
    expect(find.text('Hotel'), findsOneWidget);
    // The group header now totals only the visible category — matches
    // both the header and the (single) remaining row.
    expect(find.text('300.00 ILS'), findsNWidgets(2));
    // The hero stays trip-wide regardless of the filter.
    expect(find.text('312.50 ILS'), findsOneWidget);
  });

  testWidgets('tapping the selected pill again clears back to "All"',
      (tester) async {
    final repo = FakeExpenseRepository([
      _expense(id: 'a', category: ExpenseCategory.food, notes: 'Coffee'),
      _expense(id: 'b', category: ExpenseCategory.stay, notes: 'Hotel'),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Coffee'), findsNothing);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Coffee'), findsOneWidget);
  });

  testWidgets(
      'a category filter with no matches shows an inline message instead '
      'of the full-page empty state', (tester) async {
    final repo = FakeExpenseRepository([
      _expense(id: 'a', category: ExpenseCategory.food, notes: 'Coffee'),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();

    expect(find.text('No expenses match this filter.'), findsOneWidget);
    // The full designed empty state (with its own CTA) is for a trip with
    // zero expenses altogether, not a filter that happens to match none.
    expect(find.text('Track what this trip costs'), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
