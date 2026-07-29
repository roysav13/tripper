import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/places/presentation/places_screen.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_place_repository.dart';
import '../../helpers/fake_trip_repository.dart';

final _today = DateTime(2026, 7, 19);

Place _p(
  String name, {
  bool visited = false,
  DateTime? visitedAt,
  String country = '',
  String city = '',
}) =>
    Place(
      id: name,
      name: name,
      country: country,
      city: city,
      status: visited ? PlaceStatus.beenThere : PlaceStatus.wantToGo,
      visitedAt: visitedAt,
    );

Widget _app(List<Place> places, {List<Trip> trips = const []}) => ProviderScope(
      overrides: [
        placeRepositoryProvider
            .overrideWithValue(FakePlaceRepository([...places])),
        // Trips feed the days-away stat (M5.6) in the same header.
        tripRepositoryProvider
            .overrideWithValue(FakeTripRepository([...trips])),
        clockProvider.overrideWithValue(() => _today),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const PlacesScreen(),
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
  testWidgets('empty state invites the first place', (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();
    expect(find.text('Where to next?'), findsOneWidget);
  });

  testWidgets('sections split wishlist and visited, stats count up',
      (tester) async {
    await tester.pumpWidget(
      _app([
        _p('Railay viewpoint', city: 'Krabi', country: 'Thailand'),
        _p(
          'Phi Phi lagoon',
          visited: true,
          visitedAt: DateTime(2026, 7, 18),
          country: 'Thailand',
        ),
        _p(
          'Ein Gedi waterfall',
          visited: true,
          visitedAt: DateTime(2026, 4, 2),
          country: 'Israel',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('WANT TO GO · 1'), findsOneWidget);
    expect(find.text('BEEN THERE · 2'), findsOneWidget);
    // Stats header: 2 distinct countries, 2 visited, 0 days (no trips).
    expect(find.text('COUNTRIES'), findsOneWidget);
    expect(find.text('PLACES VISITED'), findsOneWidget);
    expect(find.text('DAYS AWAY'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2));
    expect(find.textContaining('VISITED 18 JUL 2026'), findsOneWidget);
  });

  testWidgets('days-away stat counts finished and in-progress trips only',
      (tester) async {
    await tester.pumpWidget(
      _app(
        // At least one place, or the screen shows the empty state and the
        // stats header is never built.
        [_p('Railay viewpoint', country: 'Thailand')],
        trips: [
          // Finished: 5 days.
          Trip(
            id: 'past',
            name: 'Rome',
            destinations: ['Rome'],
            startDate: DateTime(2026, 6, 1),
            endDate: DateTime(2026, 6, 5),
          ),
          // In progress (today = 19 Jul): 16-19 Jul = 4 days so far.
          Trip(
            id: 'active',
            name: 'Krabi',
            destinations: ['Krabi'],
            startDate: DateTime(2026, 7, 16),
            endDate: DateTime(2026, 7, 27),
          ),
          // Upcoming: contributes nothing.
          Trip(
            id: 'future',
            name: 'Tokyo',
            destinations: ['Tokyo'],
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 10),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DAYS AWAY'), findsOneWidget);
    expect(find.text('9'), findsOneWidget); // 5 + 4, not 5 + 12 + 10
  });

  testWidgets('check tap moves a place from wishlist to visited',
      (tester) async {
    final hapticCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          hapticCalls.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(_app([_p('Railay viewpoint')]));
    await tester.pumpAndSettle();
    expect(find.text('WANT TO GO · 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Mark as visited'));
    await tester.pumpAndSettle();

    expect(find.text('WANT TO GO · 1'), findsNothing);
    expect(find.text('BEEN THERE · 1'), findsOneWidget);
    expect(find.textContaining('VISITED 19 JUL 2026'), findsOneWidget);
    // M4.4 — mark-visited gets a quiet haptic tick.
    expect(hapticCalls, ['HapticFeedbackType.selectionClick']);
  });

  testWidgets('500+ places render without overflow or exceptions (M4.2)',
      (tester) async {
    final many = [
      for (var i = 0; i < 520; i++)
        _p(
          'Place number $i with a fairly long name for wrapping',
          visited: i.isEven,
          visitedAt: i.isEven ? DateTime(2026, 1, 1) : null,
          country: 'Country ${i % 12}',
          city: 'City ${i % 40}',
        ),
    ];
    await tester.pumpWidget(_app(many));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.fling(find.byType(ListView), const Offset(0, -5000), 3000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'row settle + icon cross-fade animations run without throwing '
      'mid-flight (M4.4)', (tester) async {
    await tester.pumpWidget(_app([_p('Railay viewpoint')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mark as visited'));
    // Pump mid-transition (well under the 250ms duration) instead of
    // settling straight away — this is what would surface a tween/curve
    // mistake that only shows up while the animation is actually running.
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(find.text('BEEN THERE · 1'), findsOneWidget);
  });
}
