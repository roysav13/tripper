import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripper/features/places/data/geocoding_service.dart';

const _fixture = '''
[
  {
    "lat": "8.0119",
    "lon": "98.8378",
    "name": "Railay Beach",
    "display_name": "Railay Beach, Ao Nang, Krabi, Thailand",
    "address": {"country": "Thailand", "town": "Ao Nang"}
  },
  {
    "lat": "41.8902",
    "lon": "12.4922",
    "name": "",
    "display_name": "Colosseum, Rome, Italy",
    "address": {"country": "Italy", "city": "Rome"}
  },
  {
    "lat": "not-a-number",
    "lon": "12.0",
    "name": "Broken",
    "display_name": "Broken entry"
  }
]
''';

void main() {
  test('parses results with address details', () {
    final results = parseNominatim(_fixture);
    expect(results, hasLength(2));

    expect(results[0].name, 'Railay Beach');
    expect(results[0].lat, closeTo(8.0119, 0.0001));
    expect(results[0].country, 'Thailand');
    expect(results[0].city, 'Ao Nang');

    // Empty name falls back to first display_name segment.
    expect(results[1].name, 'Colosseum');
    expect(results[1].city, 'Rome');
  });

  test('garbage input parses to empty, never throws', () {
    expect(parseNominatim('{}'), isEmpty);
    expect(parseNominatim('[]'), isEmpty);
    expect(parseNominatim('[{"lat": "1"}]'), isEmpty);
  });

  group('NominatimGeocoder surfaces the real failure', () {
    test('non-200 reason names Nominatim and the status code', () async {
      final client = MockClient((request) async {
        return http.Response('rate limited', 429);
      });
      final geocoder = NominatimGeocoder(client);

      await expectLater(
        () => geocoder.search('Rome'),
        throwsA(
          isA<GeocodingException>().having(
            (e) => e.reason,
            'reason',
            allOf(contains('Nominatim'), contains('429')),
          ),
        ),
      );
    });

    test('transport failure reason includes the underlying exception',
        () async {
      final client = MockClient((request) async {
        throw Exception('Failed host lookup');
      });
      final geocoder = NominatimGeocoder(client);

      await expectLater(
        () => geocoder.search('Rome'),
        throwsA(
          isA<GeocodingException>().having(
            (e) => e.reason,
            'reason',
            contains('Failed host lookup'),
          ),
        ),
      );
    });
  });
}
