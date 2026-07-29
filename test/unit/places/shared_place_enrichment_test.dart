import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/places/data/geocoding_service.dart';

class _FakeGeocoder implements Geocoder {
  _FakeGeocoder({
    this.searchResults = const [],
    this.reverseHit,
    this.fail = false,
  });

  final List<GeoResult> searchResults;
  final GeoResult? reverseHit;
  final bool fail;
  int searchCalls = 0;
  int reverseCalls = 0;

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
  Future<GeoResult?> details(String placeId) async => null;
}

const _reverseHit = GeoResult(
  name: 'Railay Beach',
  displayName: 'Railay Beach, Ao Nang, Krabi, Thailand',
  lat: 8.0119,
  lon: 98.8378,
  country: 'Thailand',
  city: 'Ao Nang',
);

void main() {
  test('coordinates get city/country from reverse geocoding', () async {
    final geocoder = _FakeGeocoder(reverseHit: _reverseHit);
    final prefill = await enrichSharedPlace(
      geocoder: geocoder,
      name: 'Railay viewpoint',
      lat: 8.0119,
      lng: 98.8378,
    );
    expect(geocoder.reverseCalls, 1);
    // The shared name wins over the reverse-geocoded one.
    expect(prefill.name, 'Railay viewpoint');
    expect(prefill.city, 'Ao Nang');
    expect(prefill.country, 'Thailand');
    expect(prefill.lat, closeTo(8.0119, 0.0001));
  });

  test('missing name falls back to the reverse-geocoded name', () async {
    final prefill = await enrichSharedPlace(
      geocoder: _FakeGeocoder(reverseHit: _reverseHit),
      lat: 8.0119,
      lng: 98.8378,
    );
    expect(prefill.name, 'Railay Beach');
  });

  test('name without coordinates is forward-searched', () async {
    final geocoder = _FakeGeocoder(searchResults: [_reverseHit]);
    final prefill = await enrichSharedPlace(
      geocoder: geocoder,
      name: 'Railay Beach',
    );
    expect(geocoder.searchCalls, 1);
    expect(prefill.lat, closeTo(8.0119, 0.0001));
    expect(prefill.country, 'Thailand');
  });

  test('offline keeps whatever the link carried', () async {
    final prefill = await enrichSharedPlace(
      geocoder: _FakeGeocoder(fail: true),
      name: 'Railay Beach',
      lat: 8.0119,
      lng: 98.8378,
    );
    expect(prefill.name, 'Railay Beach');
    expect(prefill.lat, closeTo(8.0119, 0.0001));
    expect(prefill.city, isEmpty);
  });

  test('offline with name only still yields the name', () async {
    final prefill = await enrichSharedPlace(
      geocoder: _FakeGeocoder(fail: true),
      name: 'Hidden cafe',
    );
    expect(prefill.name, 'Hidden cafe');
    expect(prefill.lat, isNull);
  });

  test('reverse parser reads address details', () {
    final hit = parseNominatimReverse('''
{
  "lat": "41.8902",
  "lon": "12.4922",
  "name": "Colosseum",
  "display_name": "Colosseum, Rome, Italy",
  "address": {"country": "Italy", "city": "Rome"}
}
''');
    expect(hit!.name, 'Colosseum');
    expect(hit.city, 'Rome');
    expect(hit.country, 'Italy');
  });
}
