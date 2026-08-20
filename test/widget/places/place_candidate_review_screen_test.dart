import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/data/geocoding_service.dart';
import 'package:tripper/features/places/data/place_summary_service.dart';
import 'package:tripper/features/places/presentation/place_candidate_review_screen.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

class _FakeWikipedia implements PlaceLocationSummaryFetcher {
  _FakeWikipedia(this.result);
  final WikipediaLookup? result;

  @override
  Future<WikipediaLookup?> lookup({
    required String name,
    String city = '',
    String country = '',
    double? lat,
    double? lng,
  }) async =>
      result;
}

class _FakeGeocoder implements Geocoder {
  _FakeGeocoder({this.reverseHit, this.searchResults = const []});
  final GeoResult? reverseHit;
  final List<GeoResult> searchResults;

  @override
  Future<List<GeoResult>> search(String query) async => searchResults;
  @override
  Future<GeoResult?> reverse(double lat, double lon) async => reverseHit;
  @override
  Future<GeoResult?> details(String placeId) async => null;
}

Future<ResolvedPlaceCandidate?> _openWith(
  WidgetTester tester, {
  required PlaceLocationSummaryFetcher wikipedia,
  required Geocoder geocoder,
  required String candidateName,
}) async {
  ResolvedPlaceCandidate? result;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      placeLocationSummaryFetcherProvider.overrideWithValue(wikipedia),
      geocoderProvider.overrideWithValue(geocoder),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await PlaceCandidateReviewScreen.open(
              context,
              candidateName: candidateName,
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('shows a loading state while resolving', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        placeLocationSummaryFetcherProvider
            .overrideWithValue(_FakeWikipedia(null)),
        geocoderProvider.overrideWithValue(_FakeGeocoder()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => PlaceCandidateReviewScreen.open(
              context,
              candidateName: 'Railay Beach',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump(); // one frame — resolution hasn't completed yet

    // skipOffstage: false — a freshly pushed MaterialPageRoute is built
    // Offstage for exactly its first frame (Flutter's default
    // HeroController measures the incoming route before starting its
    // transition; see widgets/routes.dart's `ModalRoute.offstage` doc).
    // find.text()'s default skipOffstage:true would filter this frame's
    // content out even though it's genuinely built, so the loading text
    // is invisible to a same-frame assertion unless we say so explicitly.
    expect(
      find.text('Looking up…', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('fully resolved candidate shows name, summary, location',
      (tester) async {
    final result = await _openWith(
      tester,
      wikipedia: _FakeWikipedia(
        const WikipediaLookup(
          summary: 'A limestone cove.',
          lat: 8.0119,
          lng: 98.8378,
        ),
      ),
      geocoder: _FakeGeocoder(
        reverseHit: const GeoResult(
          name: 'Railay Beach',
          displayName: 'Railay Beach, Ao Nang, Krabi, Thailand',
          lat: 8.0119,
          lon: 98.8378,
          country: 'Thailand',
          city: 'Ao Nang',
        ),
      ),
      candidateName: 'Railay Beach',
    );

    expect(find.text('Railay Beach'), findsOneWidget);
    expect(find.text('A limestone cove.'), findsOneWidget);
    expect(find.textContaining('Ao Nang'), findsOneWidget);
    // Not yet confirmed — the button tap in _openWith just opened the
    // screen, this assertion runs against the still-open review UI.
    expect(result, isNull);
  });

  testWidgets('no location resolved shows the explicit empty state',
      (tester) async {
    await _openWith(
      tester,
      wikipedia: _FakeWikipedia(null),
      geocoder: _FakeGeocoder(),
      candidateName: 'Some Obscure Place',
    );

    expect(
      find.text('No location found — you can add one manually next'),
      findsOneWidget,
    );
  });

  testWidgets('confirm returns the resolved candidate', (tester) async {
    ResolvedPlaceCandidate? result;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        placeLocationSummaryFetcherProvider.overrideWithValue(
          _FakeWikipedia(
            const WikipediaLookup(summary: 'A cove.', lat: 8.0, lng: 98.8),
          ),
        ),
        geocoderProvider.overrideWithValue(
          _FakeGeocoder(
            reverseHit: const GeoResult(
              name: 'x',
              displayName: 'x',
              lat: 8.0,
              lon: 98.8,
              country: 'Thailand',
              city: 'Krabi',
            ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await PlaceCandidateReviewScreen.open(
                context,
                candidateName: 'Railay Beach',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add this place'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Railay Beach');
    expect(result!.summary, 'A cove.');
  });

  testWidgets('cancel returns null', (tester) async {
    final result = await _openWith(
      tester,
      wikipedia: _FakeWikipedia(null),
      geocoder: _FakeGeocoder(),
      candidateName: 'Railay Beach',
    );
    // Screen is open; now cancel it.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
