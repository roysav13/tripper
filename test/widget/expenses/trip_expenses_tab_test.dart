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
  });

  testWidgets('total and category breakdown render with exact amounts',
      (tester) async {
    final repo = FakeExpenseRepository([
      _expense(id: 'a', amountMinor: 1250, category: ExpenseCategory.food),
      _expense(id: 'b', amountMinor: 30000, category: ExpenseCategory.stay),
      _expense(id: 'c', amountMinor: 750, category: ExpenseCategory.food),
    ]);
    await tester.pumpWidget(await _app(repo));
    await tester.pumpAndSettle();

    // Total: 12.50 + 300.00 + 7.50 = 320.00
    expect(find.text('320.00 ILS'), findsOneWidget);
    // Breakdown: stay 300.00 first, then food 20.00 (bare numbers —
    // single-currency trip, so the code would be noise).
    expect(find.text('300.00'), findsWidgets);
    expect(find.text('20.00'), findsOneWidget);
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
    expect(find.text('≈ 200.00 ILS'), findsOneWidget); // combined total
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

    expect(find.text('≈ 100.00 ILS'), findsOneWidget);
    expect(find.text('1 expense not converted yet'), findsOneWidget);
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
    await tester.fling(find.byType(ListView), const Offset(0, -2000), 1000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
