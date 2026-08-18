import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/places/data/nearby_places_service.dart';

const _wellFormed = '''
{
  "places": [
    {
      "id": "ChIJraily",
      "displayName": {"text": "Railay Beach Bar", "languageCode": "en"},
      "location": {"latitude": 8.0119, "longitude": 98.8378},
      "rating": 4.6,
      "userRatingCount": 512,
      "primaryType": "bar"
    },
    {
      "id": "ChIJnorating",
      "displayName": {"text": "No Rating Cafe"},
      "location": {"latitude": 8.02, "longitude": 98.84}
    }
  ]
}
''';

const _malformed = '''
{
  "places": [
    {"id": "ChIJnoname", "location": {"latitude": 8.0, "longitude": 98.0}},
    {"id": "ChIJnolocation", "displayName": {"text": "Ghost"}},
    {"displayName": {"text": "No id"}, "location": {"latitude": 8.0, "longitude": 98.0}},
    "not even a map"
  ]
}
''';

const _empty = '{"places": []}';

void main() {
  group('parseSearchNearby', () {
    test('parses a well-formed response, defaulting missing rating fields', () {
      final results = parseSearchNearby(_wellFormed);
      expect(results, hasLength(2));
      expect(results[0].placeId, 'ChIJraily');
      expect(results[0].name, 'Railay Beach Bar');
      expect(results[0].lat, 8.0119);
      expect(results[0].lng, 98.8378);
      expect(results[0].rating, 4.6);
      expect(results[0].userRatingCount, 512);
      expect(results[0].primaryType, 'bar');

      expect(results[1].name, 'No Rating Cafe');
      expect(results[1].rating, 0);
      expect(results[1].userRatingCount, 0);
      expect(results[1].primaryType, isNull);
    });

    test('skips entries missing a name, location, or id; skips non-maps', () {
      expect(parseSearchNearby(_malformed), isEmpty);
    });

    test('an empty places array gives an empty list', () {
      expect(parseSearchNearby(_empty), isEmpty);
    });

    test('a non-map body gives an empty list', () {
      expect(parseSearchNearby('[]'), isEmpty);
      expect(() => parseSearchNearby('not json'), throwsFormatException);
    });
  });
}
