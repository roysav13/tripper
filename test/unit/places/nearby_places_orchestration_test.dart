import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/places/data/nearby_places_cache.dart';
import 'package:tripper/features/places/data/nearby_places_service.dart';
import 'package:tripper/features/places/domain/nearby_place.dart';

class _FakeFetcher implements NearbyPlacesFetcher {
  var callCount = 0;
  List<NearbyPlaceResult> results = const [];

  @override
  Future<List<NearbyPlaceResult>> searchNearby({
    required double lat,
    required double lng,
  }) async {
    callCount++;
    return results;
  }
}

const _highRated = NearbyPlaceResult(
  placeId: 'p1',
  name: 'Railay Beach Bar',
  lat: 8.02,
  lng: 98.84,
  rating: 4.6,
  userRatingCount: 512,
);

void main() {
  group('NearbyPlacesService', () {
    test('a cache miss fetches, caches, filters/sorts, and reports a real fetch',
        () async {
      final fetcher = _FakeFetcher()..results = const [_highRated];
      final cache = NearbyPlacesCache();
      var realFetchCount = 0;
      var now = DateTime(2026, 8, 17, 10);
      final service = NearbyPlacesService(
        fetcher,
        cache,
        () => now,
        () async => realFetchCount++,
      );

      final results = await service.search(lat: 8.0119, lng: 98.8378);

      expect(results, [_highRated]);
      expect(fetcher.callCount, 1);
      expect(realFetchCount, 1);
    });

    test('a cache hit within the TTL skips the fetcher and the counter',
        () async {
      final fetcher = _FakeFetcher()..results = const [_highRated];
      final cache = NearbyPlacesCache();
      var realFetchCount = 0;
      var now = DateTime(2026, 8, 17, 10);
      final service = NearbyPlacesService(
        fetcher,
        cache,
        () => now,
        () async => realFetchCount++,
      );

      await service.search(lat: 8.0119, lng: 98.8378);
      now = now.add(const Duration(minutes: 30));
      final second = await service.search(lat: 8.0119, lng: 98.8378);

      expect(second, [_highRated]);
      expect(fetcher.callCount, 1);
      expect(realFetchCount, 1);
    });

    test('a lookup past the TTL fetches and increments again', () async {
      final fetcher = _FakeFetcher()..results = const [_highRated];
      final cache = NearbyPlacesCache();
      var realFetchCount = 0;
      var now = DateTime(2026, 8, 17, 10);
      final service = NearbyPlacesService(
        fetcher,
        cache,
        () => now,
        () async => realFetchCount++,
      );

      await service.search(lat: 8.0119, lng: 98.8378);
      now = now.add(const Duration(hours: 1, minutes: 1));
      await service.search(lat: 8.0119, lng: 98.8378);

      expect(fetcher.callCount, 2);
      expect(realFetchCount, 2);
    });
  });
}
