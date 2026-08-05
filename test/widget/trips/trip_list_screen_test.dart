import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/presentation/journal_providers.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/trips/presentation/trip_list_screen.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_journal_repository.dart';
import '../../helpers/fake_place_repository.dart';
import '../../helpers/fake_trip_repository.dart';
import '../../helpers/test_preferences.dart';

final _today = DateTime(2026, 7, 19);

Trip _trip(
  String id,
  String name,
  DateTime start,
  DateTime end, {
  bool archived = false,
}) =>
    Trip(
      id: id,
      name: name,
      destinations: const ['Somewhere'],
      startDate: start,
      endDate: end,
      archived: archived,
    );

GoRouter _router() => GoRouter(
      initialLocation: '/trips',
      routes: [
        GoRoute(
          path: '/trips',
          builder: (context, state) => const TripListScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) =>
                  const Scaffold(body: Text('form-screen')),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) => Scaffold(
                body: Text('detail-${state.pathParameters['id']}'),
              ),
            ),
          ],
        ),
      ],
    );

Future<Widget> _app(
  List<Trip> trips, {
  bool redirectDone = true,
  FakePlaceRepository? placeRepo,
  FakeJournalRepository? journalRepo,
  Map<String, Object> prefs = const {},
  FakeTripRepository? tripRepo,
}) async =>
    ProviderScope(
      overrides: [
        await testPreferencesOverride(prefs),
        tripRepositoryProvider
            .overrideWithValue(tripRepo ?? FakeTripRepository([...trips])),
        placeRepositoryProvider
            .overrideWithValue(placeRepo ?? FakePlaceRepository([])),
        // Repository-boundary mock (CLAUDE.md rule 5) — the completion
        // prompt routes through markPlacesVisited, which also reads
        // journalRepositoryProvider; leaving it unmocked would hit the
        // real file-backed Drift database via path_provider.
        journalRepositoryProvider
            .overrideWithValue(journalRepo ?? FakeJournalRepository([])),
        clockProvider.overrideWithValue(() => _today),
        launchRedirectDoneProvider.overrideWith((ref) => redirectDone),
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
  testWidgets('empty list shows designed empty state', (tester) async {
    await tester.pumpWidget(await _app(const []));
    await tester.pumpAndSettle();
    expect(find.text('Plan your first trip'), findsOneWidget);
  });

  testWidgets('trips land in the right buckets', (tester) async {
    await tester.pumpWidget(
      await _app([
        _trip('a', 'Active trip', DateTime(2026, 7, 16), DateTime(2026, 7, 27)),
        _trip(
          'u',
          'Upcoming trip',
          DateTime(2026, 10, 3),
          DateTime(2026, 10, 7),
        ),
        _trip('p', 'Past trip', DateTime(2026, 4, 1), DateTime(2026, 4, 5)),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('ACTIVE NOW'), findsOneWidget);
    expect(find.text('UPCOMING'), findsOneWidget);
    expect(find.text('PAST'), findsOneWidget);
    expect(find.text('Active trip'), findsOneWidget);
    expect(find.text('Day 4 of 12'), findsOneWidget);
  });

  testWidgets('dateless trip lands in PLANNED with dates TBD', (tester) async {
    await tester.pumpWidget(
      await _app([
        const Trip(
          id: 'j',
          name: 'Japan someday',
          destinations: ['Tokyo'],
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('PLANNED'), findsOneWidget);
    expect(find.textContaining('DATES TBD'), findsOneWidget);
  });

  testWidgets('archived trips are separated from buckets', (tester) async {
    await tester.pumpWidget(
      await _app([
        _trip(
          'x',
          'Old shelved',
          DateTime(2026, 1, 1),
          DateTime(2026, 1, 5),
          archived: true,
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('ARCHIVED'), findsOneWidget);
    expect(find.text('PAST'), findsNothing);
  });

  testWidgets('tapping a trip opens its detail route', (tester) async {
    await tester.pumpWidget(
      await _app([
        _trip('a', 'Active trip', DateTime(2026, 7, 16), DateTime(2026, 7, 27)),
      ]),
    );
    await tester.pumpAndSettle();
    // M4.4 — the card's trip name carries the tag TripDetailScreen's AppBar
    // title matches; a typo on either end silently breaks the Hero flight
    // (mismatched tags just don't animate — no crash — so this needs an
    // explicit check rather than trusting "it didn't throw").
    expect(
      find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'trip-name-a',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Active trip'));
    await tester.pumpAndSettle();
    expect(find.text('detail-a'), findsOneWidget);
  });
  testWidgets('finished trip offers the one-time bulk mark-visited prompt',
      (tester) async {
    final placeRepo = FakePlaceRepository([
      const Place(id: 'w1', name: 'Railay viewpoint', tripId: 'p'),
    ]);
    final journalRepo = FakeJournalRepository([]);
    await tester.pumpWidget(
      await _app(
        [_trip('p', 'Past trip', DateTime(2026, 4, 1), DateTime(2026, 4, 5))],
        placeRepo: placeRepo,
        journalRepo: journalRepo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trip finished — update your map?'), findsOneWidget);
    expect(find.text('Railay viewpoint'), findsOneWidget);

    await tester.tap(find.text('Mark visited'));
    await tester.pumpAndSettle();

    final places = await placeRepo.watchAll().first;
    expect(places.single.isVisited, isTrue);
    expect(places.single.visitedAt, DateTime(2026, 4, 5));
    // The prompt never comes back.
    expect(find.text('Trip finished — update your map?'), findsNothing);

    // Bulk-confirming the prompt routes through markPlacesVisited, which
    // must also leave a linked stub journal entry per newly-visited place.
    final entries = await journalRepo.watchForTrip('p').first;
    expect(entries, hasLength(1));
    expect(entries.single.placeId, 'w1');
    expect(entries.single.placeName, 'Railay viewpoint');
    expect(entries.single.loggedAt, DateTime(2026, 4, 5));
  });

  testWidgets(
      'backup reminder shows when trips exist and nothing was ever exported',
      (tester) async {
    await tester.pumpWidget(
      await _app([
        _trip('a', 'Active trip', DateTime(2026, 7, 16), DateTime(2026, 7, 27)),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Back up now'), findsOneWidget);
  });

  testWidgets('backup reminder is gone once a backup has been made',
      (tester) async {
    await tester.pumpWidget(
      await _app(
        [
          _trip(
            'a',
            'Active trip',
            DateTime(2026, 7, 16),
            DateTime(2026, 7, 27),
          ),
        ],
        prefs: {'has_exported_backup': true},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Back up now'), findsNothing);
  });

  testWidgets(
      'shows a designed error state if the trip stream fails, retry recovers',
      (tester) async {
    final repo = FakeTripRepository([
      _trip('a', 'Active trip', DateTime(2026, 7, 16), DateTime(2026, 7, 27)),
    ]);
    await tester.pumpWidget(await _app(const [], tripRepo: repo));
    await tester.pumpAndSettle();
    expect(find.text('Active trip'), findsOneWidget);

    repo.emitError(Exception('db unavailable'));
    await tester.pumpAndSettle();
    // M4.2 — a raw exception must never reach the screen; a designed
    // state with a way forward does.
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Active trip'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Active trip'), findsOneWidget);
  });

  testWidgets('30+ trips render without overflow or exceptions (M4.2)',
      (tester) async {
    final many = [
      for (var i = 0; i < 35; i++)
        _trip(
          'trip-$i',
          'Trip number $i with a fairly long destination name',
          DateTime(2026, 1, 1).add(Duration(days: i * 10)),
          DateTime(2026, 1, 5).add(Duration(days: i * 10)),
        ),
    ];
    await tester.pumpWidget(await _app(many));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.fling(find.byType(ListView), const Offset(0, -3000), 2000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('launch redirect opens the single active trip once',
      (tester) async {
    await tester.pumpWidget(
      await _app(
        [
          _trip(
            'a',
            'Active trip',
            DateTime(2026, 7, 16),
            DateTime(2026, 7, 27),
          ),
        ],
        redirectDone: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('detail-a'), findsOneWidget);
  });
}
