import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripper/features/places/data/place_summary_service.dart';
import 'package:tripper/features/places/domain/place.dart';

import '../../helpers/fake_place_repository.dart';

void main() {
  group('parseGeosearchTitles', () {
    test('reads titles off geosearch results, closest first', () {
      const body = '''
{"query": {"geosearch": [
  {"title": "Railay Beach", "dist": 120},
  {"title": "Ao Nang", "dist": 2500}
]}}
''';
      expect(
        parseGeosearchTitles(body),
        ['Railay Beach', 'Ao Nang'],
      );
    });

    test('no results yields an empty list', () {
      expect(parseGeosearchTitles('{"query": {"geosearch": []}}'), isEmpty);
    });

    test('garbage input never throws', () {
      expect(parseGeosearchTitles('{}'), isEmpty);
      expect(parseGeosearchTitles('[]'), isEmpty);
    });
  });

  group('parseSearchTitle', () {
    test('reads the top text-search result', () {
      const body = '''
{"query": {"search": [{"title": "Railay Beach"}, {"title": "Other"}]}}
''';
      expect(parseSearchTitle(body), 'Railay Beach');
    });

    test('no results yields null', () {
      expect(parseSearchTitle('{"query": {"search": []}}'), isNull);
    });

    test('garbage input never throws', () {
      expect(parseSearchTitle('{}'), isNull);
    });
  });

  group('parseWikipediaSummary', () {
    test('reads the extract off a standard page', () {
      const body = '''
{"type": "standard", "title": "Railay Beach", "extract": "A limestone cove."}
''';
      expect(parseWikipediaSummary(body), 'A limestone cove.');
    });

    test('disambiguation pages are rejected, not shown as a summary', () {
      const body = '''
{"type": "disambiguation", "extract": "Paris may refer to: ..."}
''';
      expect(parseWikipediaSummary(body), isNull);
    });

    test('empty/blank extract yields null, not an empty string', () {
      expect(
        parseWikipediaSummary('{"type": "standard", "extract": "   "}'),
        isNull,
      );
    });

    test('garbage input never throws', () {
      expect(parseWikipediaSummary('{}'), isNull);
    });
  });

  group('pickBestGeoMatch', () {
    test('accepts a candidate sharing a significant word with the name', () {
      expect(
        pickBestGeoMatch(['Ao Nang', 'Railay Beach'], 'Railay Viewpoint'),
        'Railay Beach',
      );
    });

    test(
        'rejects the nearest candidate when nothing agrees on wording — '
        'proximity alone is not enough evidence', () {
      expect(
        pickBestGeoMatch(['Ao Nang Resort', 'Some Other Place'], 'Railay'),
        isNull,
      );
    });

    test('short/generic words (under 4 letters) never count as a match', () {
      // "The Bar" only shares "the"/"bar"-length words too short to trust.
      expect(pickBestGeoMatch(['The Bar'], 'The Inn'), isNull);
    });

    test('empty candidate list yields null', () {
      expect(pickBestGeoMatch(const [], 'Railay Beach'), isNull);
    });
  });

  group('WikipediaPlaceSummaryFetcher', () {
    test(
        'with coordinates: geosearch match short-circuits straight to the '
        'summary fetch, skipping text search', () async {
      final requestedPaths = <String>[];
      final client = MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path == '/w/api.php') {
          expect(request.url.queryParameters['list'], 'geosearch');
          expect(request.url.queryParameters['gscoord'], '8.0119|98.8378');
          return http.Response(
            '{"query": {"geosearch": [{"title": "Railay Beach"}]}}',
            200,
          );
        }
        expect(request.url.path, '/api/rest_v1/page/summary/Railay_Beach');
        return http.Response(
          '{"type": "standard", "extract": "A limestone cove."}',
          200,
        );
      });
      final fetcher = WikipediaPlaceSummaryFetcher(client);

      final result = await fetcher.fetchSummary(
        name: 'Railay Beach',
        city: 'Krabi',
        country: 'Thailand',
        lat: 8.0119,
        lng: 98.8378,
      );

      expect(result, 'A limestone cove.');
      expect(
        requestedPaths,
        ['/w/api.php', '/api/rest_v1/page/summary/Railay_Beach'],
      );
    });

    test(
        'geosearch with no name-agreeing candidate falls back to text '
        'search', () async {
      final calls = <Map<String, String>>[];
      final client = MockClient((request) async {
        if (request.url.path == '/w/api.php') {
          calls.add(request.url.queryParameters);
          if (request.url.queryParameters['list'] == 'geosearch') {
            return http.Response(
              '{"query": {"geosearch": [{"title": "Unrelated Resort"}]}}',
              200,
            );
          }
          expect(
            request.url.queryParameters['srsearch'],
            'Railay Viewpoint Krabi Thailand',
          );
          return http.Response(
            '{"query": {"search": [{"title": "Railay Viewpoint"}]}}',
            200,
          );
        }
        return http.Response(
          '{"type": "standard", "extract": "A jungle lookout."}',
          200,
        );
      });
      final fetcher = WikipediaPlaceSummaryFetcher(client);

      final result = await fetcher.fetchSummary(
        name: 'Railay Viewpoint',
        city: 'Krabi',
        country: 'Thailand',
        lat: 8.0119,
        lng: 98.8378,
      );

      expect(result, 'A jungle lookout.');
      expect(calls.map((c) => c['list']), ['geosearch', 'search']);
    });

    test('no coordinates goes straight to text search', () async {
      var geosearchCalled = false;
      final client = MockClient((request) async {
        if (request.url.queryParameters['list'] == 'geosearch') {
          geosearchCalled = true;
        }
        if (request.url.path == '/w/api.php') {
          return http.Response(
            '{"query": {"search": [{"title": "Corner Store"}]}}',
            200,
          );
        }
        return http.Response('{"type": "standard", "extract": "A shop."}', 200);
      });
      final fetcher = WikipediaPlaceSummaryFetcher(client);

      final result = await fetcher.fetchSummary(name: 'Corner Store');

      expect(result, 'A shop.');
      expect(geosearchCalled, isFalse);
    });

    test('disambiguation result degrades to null', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/w/api.php') {
          return http.Response(
            '{"query": {"search": [{"title": "Paris"}]}}',
            200,
          );
        }
        return http.Response('{"type": "disambiguation"}', 200);
      });
      final fetcher = WikipediaPlaceSummaryFetcher(client);

      expect(await fetcher.fetchSummary(name: 'Paris'), isNull);
    });

    test('no search match at all degrades to null', () async {
      final client = MockClient(
        (request) async => http.Response('{"query": {"search": []}}', 200),
      );
      final fetcher = WikipediaPlaceSummaryFetcher(client);

      expect(await fetcher.fetchSummary(name: 'Zzzzznotaplace'), isNull);
    });

    test('non-200 response degrades to null, never throws', () async {
      final client = MockClient((request) async => http.Response('nope', 500));
      final fetcher = WikipediaPlaceSummaryFetcher(client);

      expect(await fetcher.fetchSummary(name: 'Railay Beach'), isNull);
    });

    test('transport failure degrades to null, never throws', () async {
      final client = MockClient((request) async => throw Exception('down'));
      final fetcher = WikipediaPlaceSummaryFetcher(client);

      expect(await fetcher.fetchSummary(name: 'Railay Beach'), isNull);
    });

    test('blank name is never even sent to the network', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      });
      final fetcher = WikipediaPlaceSummaryFetcher(client);

      expect(await fetcher.fetchSummary(name: '   '), isNull);
      expect(called, isFalse);
    });
  });

  test('NoopPlaceSummaryFetcher always returns null', () async {
    const fetcher = NoopPlaceSummaryFetcher();
    expect(await fetcher.fetchSummary(name: 'Anywhere'), isNull);
  });

  group('fetchAndStorePlaceSummary', () {
    test('stores the fetched text', () async {
      final repo = FakePlaceRepository([
        const Place(id: 'p1', name: 'Railay Beach'),
      ]);
      await fetchAndStorePlaceSummary(
        fetcher: _FixedFetcher('A limestone cove.'),
        repo: repo,
        placeId: 'p1',
        name: 'Railay Beach',
      );
      final place = (await repo.watchAll().first).single;
      expect(place.summary, 'A limestone cove.');
      expect(place.summaryFetchedAt, isNotNull);
    });

    test('a null fetch result still stamps the attempt', () async {
      final repo = FakePlaceRepository([
        const Place(id: 'p1', name: 'Corner store'),
      ]);
      await fetchAndStorePlaceSummary(
        fetcher: const NoopPlaceSummaryFetcher(),
        repo: repo,
        placeId: 'p1',
        name: 'Corner store',
      );
      final place = (await repo.watchAll().first).single;
      expect(place.summary, isNull);
      expect(place.summaryFetchedAt, isNotNull);
    });
  });
}

class _FixedFetcher implements PlaceSummaryFetcher {
  _FixedFetcher(this.result);
  final String? result;

  @override
  Future<String?> fetchSummary({
    required String name,
    String city = '',
    String country = '',
    double? lat,
    double? lng,
  }) async =>
      result;
}
