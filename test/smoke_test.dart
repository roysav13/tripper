import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/app.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/security/vault_lock.dart';
import 'package:tripper/features/expenses/presentation/expense_providers.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/features/vault/presentation/document_providers.dart';

import 'helpers/fake_document_repository.dart';
import 'helpers/fake_expense_repository.dart';
import 'helpers/fake_place_repository.dart';
import 'helpers/fake_trip_repository.dart';
import 'helpers/test_preferences.dart';

Future<Widget> _app() async => ProviderScope(
      overrides: [
        await testPreferencesOverride(),
        testSharesOverride(),
        tripRepositoryProvider.overrideWithValue(FakeTripRepository([])),
        documentRepositoryProvider
            .overrideWithValue(FakeDocumentRepository([])),
        placeRepositoryProvider.overrideWithValue(FakePlaceRepository([])),
        // Without this the M5.5b conversion wiring reaches the real Drift
        // database (via expensesDao), opening a second AppDatabase.
        expenseRepositoryProvider.overrideWithValue(FakeExpenseRepository()),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
        launchRedirectDoneProvider.overrideWith((ref) => true),
        biometricAuthenticatorProvider.overrideWithValue((_) async => true),
      ],
      child: const TripperApp(),
    );

void main() {
  testWidgets('app boots to the 3-tab shell', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.text('Tripper'), findsOneWidget);
  });

  testWidgets('tabs switch between the three sections', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vault'));
    await tester.pumpAndSettle();
    expect(find.text('Your documents, ready anywhere'), findsOneWidget);

    await tester.tap(find.text('Places'));
    await tester.pumpAndSettle();
    expect(find.text('Where to next?'), findsOneWidget);

    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();
    expect(find.text('Plan your first trip'), findsOneWidget);
  });

  testWidgets('settings opens from the trips header once unlocked',
      (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    // The fake authenticator passes, so the gate resolves immediately.
    expect(find.text('APPEARANCE'), findsOneWidget);

    // Backup sits below the fold now that Notifications and Home
    // currency were added above it, so scroll rather than assuming the
    // whole screen is laid out at once.
    await tester.scrollUntilVisible(
      find.text('Export backup'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Export backup'), findsOneWidget);
  });

  testWidgets('settings stays locked when auth is refused', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          await testPreferencesOverride(),
          testSharesOverride(),
          tripRepositoryProvider.overrideWithValue(FakeTripRepository([])),
          documentRepositoryProvider
              .overrideWithValue(FakeDocumentRepository([])),
          placeRepositoryProvider.overrideWithValue(FakePlaceRepository([])),
          clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
          launchRedirectDoneProvider.overrideWith((ref) => true),
          biometricAuthenticatorProvider.overrideWithValue((_) async => false),
        ],
        child: const TripperApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings locked'), findsOneWidget);
    expect(find.text('Export backup'), findsNothing);
  });
}
