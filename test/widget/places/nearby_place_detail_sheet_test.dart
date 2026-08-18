import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/data/place_summary_service.dart';
import 'package:tripper/features/places/domain/nearby_place.dart';
import 'package:tripper/features/places/presentation/nearby_place_detail_sheet.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_place_repository.dart';
import '../../helpers/fake_trip_repository.dart';

class _FakeSummaryFetcher implements PlaceSummaryFetcher {
  _FakeSummaryFetcher(this._summary, {this.delay = Duration.zero, this.gate});
  final String? _summary;
  final Duration delay;

  /// When set, `fetchSummary` blocks on this instead of [delay] — lets a
  /// test hold a fetch open indefinitely (no real-clock race with widget
  /// pumping) and release it explicitly once it's done asserting the
  /// mid-fetch state.
  final Completer<void>? gate;
  var callCount = 0;

  @override
  Future<String?> fetchSummary({
    required String name,
    String city = '',
    String country = '',
    double? lat,
    double? lng,
  }) async {
    callCount++;
    if (gate != null) {
      await gate!.future;
    } else if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return _summary;
  }
}

const _result = NearbyPlaceResult(
  placeId: 'p1',
  name: 'Railay Beach Bar',
  lat: 8.02,
  lng: 98.84,
  rating: 4.6,
  userRatingCount: 512,
);

Widget _app({
  required PlaceSummaryFetcher fetcher,
  String? tripId,
  Trip? trip,
}) =>
    ProviderScope(
      overrides: [
        placeSummaryFetcherProvider.overrideWithValue(fetcher),
        placeRepositoryProvider.overrideWithValue(FakePlaceRepository([])),
        tripRepositoryProvider
            .overrideWithValue(FakeTripRepository(trip == null ? [] : [trip])),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showNearbyPlaceDetailSheet(
                context,
                result: _result,
                distanceKm: 1.2,
                tripId: tripId,
              ),
              child: const Text('open'),
            ),
          ),
        ),
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
  testWidgets('shows a spinner while the summary loads, then the text',
      (tester) async {
    final fetcher = _FakeSummaryFetcher(
      'A quiet cove with cliffside bars.',
      delay: const Duration(milliseconds: 50),
    );
    await tester.pumpWidget(_app(fetcher: fetcher));
    await tester.tap(find.text('open'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('A quiet cove with cliffside bars.'), findsOneWidget);
  });

  testWidgets('a null summary renders nothing extra, no error copy',
      (tester) async {
    await tester.pumpWidget(_app(fetcher: _FakeSummaryFetcher(null)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('no day picker without a fully-dated trip', (tester) async {
    await tester.pumpWidget(
      _app(fetcher: _FakeSummaryFetcher(null), tripId: 't1'),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Assign a day'), findsNothing);
  });

  testWidgets('day picker appears for a fully-dated trip, clamped to its range',
      (tester) async {
    final trip = Trip(
      id: 't1',
      name: 'Thailand',
      destinations: const [],
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 10),
    );
    await tester.pumpWidget(
      _app(fetcher: _FakeSummaryFetcher(null), tripId: 't1', trip: trip),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Assign a day'), findsOneWidget);
  });

  testWidgets(
      'adding after the summary resolved calls setSummary directly, not a second fetch',
      (tester) async {
    final fetcher = _FakeSummaryFetcher('A quiet cove.');
    await tester.pumpWidget(_app(fetcher: fetcher));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(fetcher.callCount, 1);

    await tester.tap(find.text('Add to wishlist'));
    await tester.pumpAndSettle();

    expect(fetcher.callCount, 1);
  });

  testWidgets(
      'adding before the summary resolves falls back to the '
      'fire-and-forget path', (tester) async {
    final gate = Completer<void>();
    final fetcher = _FakeSummaryFetcher('A quiet cove.', gate: gate);
    await tester.pumpWidget(_app(fetcher: fetcher));
    await tester.tap(find.text('open'));
    // A first pump starts the sheet-open transition's ticker (its elapsed
    // time baselines at that frame); a second, longer pump then advances
    // it to completion. Neither is pumpAndSettle — that loops forever on
    // the still-spinning loading indicator. The initState fetch stays in
    // flight throughout — it's blocked on `gate`, not a real-clock delay,
    // so none of this can race it into resolving early.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(fetcher.callCount, 1);

    await tester.tap(find.text('Add to wishlist'));
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();

    // The fire-and-forget fallback fetches again rather than awaiting or
    // reusing the still-in-flight initState fetch — an accepted duplicate
    // call in this early-tap case, per the design (a second fetch is
    // simpler and cheaper than coordinating with the in-flight one).
    expect(fetcher.callCount, 2);
  });
}
