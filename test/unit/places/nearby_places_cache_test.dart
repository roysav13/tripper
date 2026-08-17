import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/places/data/nearby_places_cache.dart';
import 'package:tripper/features/places/domain/nearby_place.dart';

const _result = NearbyPlaceResult(
  placeId: 'p1',
  name: 'Railay Beach Bar',
  lat: 8.0119,
  lng: 98.8378,
  rating: 4.6,
  userRatingCount: 512,
);

void main() {
  group('NearbyPlacesCache', () {
    test('a miss on an empty cache returns null', () {
      final cache = NearbyPlacesCache();
      expect(cache.lookup(8.0119, 98.8378, DateTime(2026, 8, 17)), isNull);
    });

    test('a hit within the TTL returns the stored results', () {
      final cache = NearbyPlacesCache();
      final storedAt = DateTime(2026, 8, 17, 10);
      cache.store(8.0119, 98.8378, const [_result], storedAt);

      final hit = cache.lookup(
        8.0119,
        98.8378,
        storedAt.add(const Duration(minutes: 59)),
      );
      expect(hit, const [_result]);
    });

    test('a lookup past the TTL is a miss', () {
      final cache = NearbyPlacesCache();
      final storedAt = DateTime(2026, 8, 17, 10);
      cache.store(8.0119, 98.8378, const [_result], storedAt);

      final miss = cache.lookup(
        8.0119,
        98.8378,
        storedAt.add(const Duration(hours: 1, minutes: 1)),
      );
      expect(miss, isNull);
    });

    test('coordinates rounded to different 3-decimal keys are distinct', () {
      final cache = NearbyPlacesCache();
      final now = DateTime(2026, 8, 17);
      cache.store(8.0119, 98.8378, const [_result], now);

      expect(cache.lookup(8.0219, 98.8378, now), isNull);
    });

    test('coordinates within the same 3-decimal rounding hit the same key',
        () {
      final cache = NearbyPlacesCache();
      final now = DateTime(2026, 8, 17);
      cache.store(8.01190001, 98.83780001, const [_result], now);

      expect(cache.lookup(8.0119, 98.8378, now), const [_result]);
    });
  });
}
