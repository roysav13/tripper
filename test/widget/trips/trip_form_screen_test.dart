import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/trips/presentation/trip_form_screen.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_trip_repository.dart';

GoRouter _router() => GoRouter(
      initialLocation: '/trips/new',
      routes: [
        GoRoute(
          path: '/trips',
          builder: (context, state) => const Scaffold(body: Text('trips-list')),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const TripFormScreen(),
            ),
          ],
        ),
      ],
    );

Widget _app(FakeTripRepository repo) => ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router(),
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
  testWidgets('defaults to the first trip color and creates with it', (
    tester,
  ) async {
    final repo = FakeTripRepository([]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Thailand');
    // Unsubmitted destination text still counts — _save() re-runs
    // _addDestination() itself, so no need to submit the field here.
    await tester.enterText(find.byType(TextField).at(1), 'Krabi');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final trips = await repo.watchTrips().first;
    expect(trips, hasLength(1));
    expect(trips.single.colorTag, 0);
  });

  testWidgets('picking a swatch saves that colorTag', (tester) async {
    final repo = FakeTripRepository([]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Thailand');
    await tester.enterText(find.byType(TextField).at(1), 'Krabi');
    await tester.pump();

    // Semantics label is 1-based ("Trip color option 3" == colorTag 2).
    await tester.tap(find.bySemanticsLabel('Trip color option 3'));
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final trips = await repo.watchTrips().first;
    expect(trips.single.colorTag, 2);
  });

  testWidgets('editing a trip preserves its existing color unless changed', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final repo = FakeTripRepository([]);
    await repo.createTrip(
      name: 'Japan',
      destinations: const ['Tokyo'],
      colorTag: 4,
    );
    final existing = (await repo.watchTrips().first).single;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: TripFormScreen(initial: existing),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Selected swatch (index 4) is marked selected in Semantics.
    // matchesSemantics asserts an exact set of actions/flags, so the
    // InkWell-derived tap/focus actions and focusable/selected-state flags
    // need to be listed explicitly, not just the ones this test cares about.
    expect(
      tester.getSemantics(find.bySemanticsLabel('Trip color option 5')),
      matchesSemantics(
        label: 'Trip color option 5',
        isButton: true,
        isSelected: true,
        isFocusable: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });
}
