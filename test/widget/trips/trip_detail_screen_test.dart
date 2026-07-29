import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/expenses/presentation/expense_providers.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/trips/presentation/trip_detail_screen.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/features/vault/presentation/document_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_document_repository.dart';
import '../../helpers/fake_expense_repository.dart';
import '../../helpers/fake_place_repository.dart';
import '../../helpers/fake_trip_repository.dart';
import '../../helpers/test_preferences.dart';

final _today = DateTime(2026, 7, 19);

Trip _trip({DateTime? start, DateTime? end}) => Trip(
      id: 't1',
      name: 'Thailand',
      destinations: const ['Krabi'],
      startDate: start,
      endDate: end,
      completionPromptShown: true,
    );

Future<Widget> _app(Trip trip) async => ProviderScope(
      overrides: [
        await testPreferencesOverride(),
        tripRepositoryProvider.overrideWithValue(FakeTripRepository([trip])),
        documentRepositoryProvider
            .overrideWithValue(FakeDocumentRepository([])),
        placeRepositoryProvider.overrideWithValue(FakePlaceRepository([])),
        expenseRepositoryProvider.overrideWithValue(FakeExpenseRepository()),
        clockProvider.overrideWithValue(() => _today),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const TripDetailScreen(tripId: 't1'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

/// Which tab body is on screen — more robust than reading TabController
/// internals, and it fails loudly if the tab order is ever shuffled.
void expectTabShowing(String text) => expect(find.text(text), findsWidgets);

void main() {
  testWidgets(
      'an active trip opens on Spend — the tab you actually use '
      'while travelling', (tester) async {
    // today (19 Jul) sits inside the trip.
    final trip = _trip(
      start: DateTime(2026, 7, 16),
      end: DateTime(2026, 7, 27),
    );
    await tester.pumpWidget(await _app(trip));
    await tester.pumpAndSettle();

    // The Spend tab's empty state, not the Documents one.
    expectTabShowing('Track what this trip costs');
  });

  testWidgets(
      'an upcoming trip still opens on Documents — packing comes '
      'before spending', (tester) async {
    final trip = _trip(
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 14),
    );
    await tester.pumpWidget(await _app(trip));
    await tester.pumpAndSettle();

    expect(find.text('Track what this trip costs'), findsNothing);
  });

  testWidgets('a past trip opens on Documents', (tester) async {
    final trip = _trip(
      start: DateTime(2026, 1, 1),
      end: DateTime(2026, 1, 10),
    );
    await tester.pumpWidget(await _app(trip));
    await tester.pumpAndSettle();

    expect(find.text('Track what this trip costs'), findsNothing);
  });

  testWidgets('a planned trip (no dates) opens on Documents', (tester) async {
    await tester.pumpWidget(await _app(_trip()));
    await tester.pumpAndSettle();

    expect(find.text('Track what this trip costs'), findsNothing);
  });

  testWidgets('all three tabs are reachable from an active trip',
      (tester) async {
    final trip = _trip(
      start: DateTime(2026, 7, 16),
      end: DateTime(2026, 7, 27),
    );
    await tester.pumpWidget(await _app(trip));
    await tester.pumpAndSettle();

    for (final tab in ['Documents', 'Places']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }

    await tester.tap(find.text('Spend'));
    await tester.pumpAndSettle();
    expectTabShowing('Track what this trip costs');
  });

  testWidgets(
      'the withdrawn Plan tab is gone — a stray fourth tab would mean '
      'the revert was only half applied', (tester) async {
    final trip = _trip(
      start: DateTime(2026, 7, 16),
      end: DateTime(2026, 7, 27),
    );
    await tester.pumpWidget(await _app(trip));
    await tester.pumpAndSettle();

    expect(find.byType(Tab), findsNWidgets(3));
    expect(find.text('Plan'), findsNothing);
  });
}
