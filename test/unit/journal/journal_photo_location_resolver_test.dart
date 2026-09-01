import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/journal/data/journal_photo_location_resolver.dart';
import 'package:tripper/features/places/data/geocoding_service.dart';
import 'package:tripper/features/places/data/place_summary_service.dart';

class _FakeNearbyArticleFetcher implements NearbyArticleFetcher {
  _FakeNearbyArticleFetcher(this.title, {this.fail = false});
  final String? title;
  final bool fail;

  @override
  Future<String?> nearestArticleTitle(double lat, double lng) async {
    if (fail) throw Exception('down');
    return title;
  }
}

class _FakeGeocoder implements Geocoder {
  _FakeGeocoder({this.reverseHit, this.fail = false});
  final GeoResult? reverseHit;
  final bool fail;
  int reverseCalls = 0;

  @override
  Future<List<GeoResult>> search(String query) async => const [];

  @override
  Future<GeoResult?> reverse(double lat, double lon) async {
    reverseCalls++;
    if (fail) throw const GeocodingException();
    return reverseHit;
  }

  @override
  Future<GeoResult?> details(String placeId) async => null;
}

void main() {
  group('resolveJournalPhotoLocationName', () {
    test(
        'Wikipedia has a nearby article: its title wins, geocoder is never '
        'called', () async {
      final wikipedia = _FakeNearbyArticleFetcher('Railay Beach');
      final geocoder = _FakeGeocoder(
        reverseHit: const GeoResult(
          name: 'Somewhere Else',
          displayName: '',
          lat: 8.0,
          lon: 98.8,
        ),
      );

      final name = await resolveJournalPhotoLocationName(
        lat: 8.0119,
        lng: 98.8378,
        wikipedia: wikipedia,
        geocoder: geocoder,
      );

      expect(name, 'Railay Beach');
      expect(geocoder.reverseCalls, 0);
    });

    test('Wikipedia finds nothing nearby: falls back to reverse geocoding',
        () async {
      final wikipedia = _FakeNearbyArticleFetcher(null);
      final geocoder = _FakeGeocoder(
        reverseHit: const GeoResult(
          name: 'Ao Nang',
          displayName: '',
          lat: 8.0,
          lon: 98.8,
        ),
      );

      final name = await resolveJournalPhotoLocationName(
        lat: 8.0,
        lng: 98.8,
        wikipedia: wikipedia,
        geocoder: geocoder,
      );

      expect(name, 'Ao Nang');
      expect(geocoder.reverseCalls, 1);
    });

    test('Wikipedia throws: degrades to reverse geocoding, never throws',
        () async {
      final wikipedia = _FakeNearbyArticleFetcher(null, fail: true);
      final geocoder = _FakeGeocoder(
        reverseHit:
            const GeoResult(name: 'Ao Nang', displayName: '', lat: 8, lon: 98),
      );

      final name = await resolveJournalPhotoLocationName(
        lat: 8.0,
        lng: 98.8,
        wikipedia: wikipedia,
        geocoder: geocoder,
      );

      expect(name, 'Ao Nang');
    });

    test('both fail or find nothing: yields null, never throws', () async {
      final wikipedia = _FakeNearbyArticleFetcher(null);
      final geocoder = _FakeGeocoder(fail: true);

      final name = await resolveJournalPhotoLocationName(
        lat: 8.0,
        lng: 98.8,
        wikipedia: wikipedia,
        geocoder: geocoder,
      );

      expect(name, isNull);
    });
  });
}
