import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/places/data/geocoding_service.dart';
import 'package:tripper/features/places/data/place_candidate_resolver.dart';
import 'package:tripper/features/places/data/place_summary_service.dart';

class _FakeWikipedia implements PlaceLocationSummaryFetcher {
  _FakeWikipedia(this.result, {this.fail = false});
  final WikipediaLookup? result;
  final bool fail;

  @override
  Future<WikipediaLookup?> lookup({
    required String name,
    String city = '',
    String country = '',
    double? lat,
    double? lng,
  }) async {
    if (fail) throw Exception('down');
    return result;
  }
}

class _FakeGeocoder implements Geocoder {
  _FakeGeocoder({
    this.searchResults = const [],
    this.reverseHit,
    this.detailsHit,
    this.fail = false,
  });
  final List<GeoResult> searchResults;
  final GeoResult? reverseHit;
  final GeoResult? detailsHit;
  final bool fail;
  int reverseCalls = 0;
  int searchCalls = 0;

  @override
  Future<List<GeoResult>> search(String query) async {
    searchCalls++;
    if (fail) throw const GeocodingException();
    return searchResults;
  }

  @override
  Future<GeoResult?> reverse(double lat, double lon) async {
    reverseCalls++;
    if (fail) throw const GeocodingException();
    return reverseHit;
  }

  @override
  Future<GeoResult?> details(String placeId) async {
    if (fail) throw const GeocodingException();
    return detailsHit;
  }
}

void main() {
  group('resolvePlaceCandidate', () {
    test(
        'Wikipedia has coordinates: Places is only used to reverse-geocode '
        'city/country, never a forward search', () async {
      final wikipedia = _FakeWikipedia(
        const WikipediaLookup(
          summary: 'A limestone cove.',
          lat: 8.0119,
          lng: 98.8378,
        ),
      );
      final geocoder = _FakeGeocoder(
        reverseHit: const GeoResult(
          name: 'Railay Beach',
          displayName: 'Railay Beach, Ao Nang, Krabi, Thailand',
          lat: 8.0119,
          lon: 98.8378,
          country: 'Thailand',
          city: 'Ao Nang',
        ),
      );

      final result = await resolvePlaceCandidate(
        wikipedia: wikipedia,
        geocoder: geocoder,
        name: 'Railay Beach',
      );

      expect(result.summary, 'A limestone cove.');
      expect(result.lat, 8.0119);
      expect(result.lng, 98.8378);
      expect(result.country, 'Thailand');
      expect(result.city, 'Ao Nang');
      expect(geocoder.searchCalls, 0);
      expect(geocoder.reverseCalls, 1);
    });

    test(
        'Wikipedia has no coordinates: Places forward-search fills '
        'location, reverse is never called', () async {
      final wikipedia = _FakeWikipedia(
        const WikipediaLookup(summary: 'A jungle lookout.'),
      );
      final geocoder = _FakeGeocoder(
        searchResults: const [
          GeoResult(
            name: 'Railay Viewpoint',
            displayName: 'Railay Viewpoint, Krabi, Thailand',
            lat: 8.02,
            lon: 98.84,
            country: 'Thailand',
            city: 'Krabi',
          ),
        ],
      );

      final result = await resolvePlaceCandidate(
        wikipedia: wikipedia,
        geocoder: geocoder,
        name: 'Railay Viewpoint',
      );

      expect(result.summary, 'A jungle lookout.');
      expect(result.lat, 8.02);
      expect(result.lng, 98.84);
      expect(result.city, 'Krabi');
      expect(geocoder.reverseCalls, 0);
      expect(geocoder.searchCalls, 1);
    });

    test('Wikipedia finds nothing: Places is the sole source', () async {
      final wikipedia = _FakeWikipedia(null);
      final geocoder = _FakeGeocoder(
        searchResults: const [
          GeoResult(
            name: 'Corner Store',
            displayName: 'Corner Store, Somewhere',
            lat: 1,
            lon: 2,
            country: 'Nowhere',
            city: 'Somewhere',
          ),
        ],
      );

      final result = await resolvePlaceCandidate(
        wikipedia: wikipedia,
        geocoder: geocoder,
        name: 'Corner Store',
      );

      expect(result.summary, isNull);
      expect(result.lat, 1);
      expect(result.city, 'Somewhere');
    });

    test('Google autocomplete result needing details resolves them',
        () async {
      final wikipedia = _FakeWikipedia(null);
      final geocoder = _FakeGeocoder(
        searchResults: const [
          GeoResult(
            name: 'Railay',
            displayName: 'Railay, Thailand',
            lat: 0,
            lon: 0,
            placeId: 'abc',
          ),
        ],
        detailsHit: const GeoResult(
          name: 'Railay',
          displayName: 'Railay, Thailand',
          lat: 8.0,
          lon: 98.8,
          country: 'Thailand',
          city: 'Krabi',
        ),
      );

      final result = await resolvePlaceCandidate(
        wikipedia: wikipedia,
        geocoder: geocoder,
        name: 'Railay',
      );

      expect(result.lat, 8.0);
      expect(result.city, 'Krabi');
    });

    test('everything fails: still returns a name-only candidate, never '
        'throws', () async {
      final wikipedia = _FakeWikipedia(null, fail: true);
      final geocoder = _FakeGeocoder(fail: true);

      final result = await resolvePlaceCandidate(
        wikipedia: wikipedia,
        geocoder: geocoder,
        name: 'Somewhere',
      );

      expect(result.name, 'Somewhere');
      expect(result.hasLocation, isFalse);
      expect(result.summary, isNull);
    });

    test('Wikipedia has coordinates but Places reverse-geocode fails: '
        'coordinates and summary survive, city/country stay empty',
        () async {
      final wikipedia = _FakeWikipedia(
        const WikipediaLookup(summary: 'A cove.', lat: 8.0, lng: 98.8),
      );
      final geocoder = _FakeGeocoder(fail: true);

      final result = await resolvePlaceCandidate(
        wikipedia: wikipedia,
        geocoder: geocoder,
        name: 'Railay Beach',
      );

      expect(result.summary, 'A cove.');
      expect(result.lat, 8.0);
      expect(result.country, '');
    });
  });
}
