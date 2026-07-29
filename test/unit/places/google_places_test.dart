import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/places/data/google_places_geocoder.dart';

const _autocomplete = '''
{
  "suggestions": [
    {
      "placePrediction": {
        "placeId": "ChIJrail",
        "text": {"text": "Railay Beach, Krabi, Thailand"},
        "structuredFormat": {
          "mainText": {"text": "Railay Beach"},
          "secondaryText": {"text": "Krabi, Thailand"}
        }
      }
    },
    {"queryPrediction": {"text": {"text": "railway stations"}}}
  ]
}
''';

const _details = '''
{
  "id": "ChIJrail",
  "displayName": {"text": "Railay Beach", "languageCode": "en"},
  "formattedAddress": "Railay Beach, Ao Nang, Krabi 81180, Thailand",
  "location": {"latitude": 8.0119, "longitude": 98.8378},
  "addressComponents": [
    {"longText": "Ao Nang", "types": ["locality", "political"]},
    {"longText": "Thailand", "types": ["country", "political"]}
  ]
}
''';

const _reverse = '''
{
  "results": [
    {
      "formatted_address": "Colosseum, Piazza del Colosseo, Rome, Italy",
      "geometry": {"location": {"lat": 41.8902, "lng": 12.4922}},
      "address_components": [
        {"long_name": "Rome", "types": ["locality", "political"]},
        {"long_name": "Italy", "types": ["country", "political"]}
      ]
    }
  ]
}
''';

void main() {
  group('autocomplete', () {
    test('maps place predictions and skips query predictions', () {
      final results = parseGooglePredictions(_autocomplete);
      expect(results, hasLength(1));
      expect(results.single.name, 'Railay Beach');
      expect(results.single.displayName, 'Krabi, Thailand');
      expect(results.single.placeId, 'ChIJrail');
      // Autocomplete carries no coordinates yet.
      expect(results.single.needsDetails, isTrue);
    });

    test('garbage input yields no results, never throws', () {
      expect(parseGooglePredictions('{}'), isEmpty);
      expect(parseGooglePredictions('[]'), isEmpty);
      expect(parseGooglePredictions('{"suggestions":[{}]}'), isEmpty);
    });
  });

  group('place details', () {
    test('resolves coordinates, city and country', () {
      final hit = parseGooglePlaceDetails(_details)!;
      expect(hit.name, 'Railay Beach');
      expect(hit.lat, closeTo(8.0119, 0.0001));
      expect(hit.lon, closeTo(98.8378, 0.0001));
      expect(hit.city, 'Ao Nang');
      expect(hit.country, 'Thailand');
      expect(hit.needsDetails, isFalse);
    });

    test('missing location returns null', () {
      expect(parseGooglePlaceDetails('{"id":"x"}'), isNull);
    });
  });

  group('reverse geocoding', () {
    test('reads the first result', () {
      final hit = parseGoogleReverse(_reverse)!;
      expect(hit.city, 'Rome');
      expect(hit.country, 'Italy');
      expect(hit.lat, closeTo(41.8902, 0.0001));
    });

    test('empty results return null', () {
      expect(parseGoogleReverse('{"results":[]}'), isNull);
    });
  });
}
