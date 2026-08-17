import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/places/domain/nearby_place.dart';
import 'package:tripper/features/places/domain/place.dart';

NearbyPlaceResult _r(
  String name, {
  double rating = 4.5,
  int userRatingCount = 20,
  double lat = 13.7563,
  double lng = 100.5018,
  String? primaryType,
}) =>
    NearbyPlaceResult(
      placeId: name,
      name: name,
      lat: lat,
      lng: lng,
      rating: rating,
      userRatingCount: userRatingCount,
      primaryType: primaryType,
    );

void main() {
  group('nearbyCategoryFor', () {
    test('maps known Google types to PlaceCategory', () {
      expect(nearbyCategoryFor('restaurant'), PlaceCategory.restaurant);
      expect(nearbyCategoryFor('cafe'), PlaceCategory.coffeeShop);
      expect(nearbyCategoryFor('bar'), PlaceCategory.bar);
      expect(nearbyCategoryFor('museum'), PlaceCategory.museum);
      expect(nearbyCategoryFor('tourist_attraction'), PlaceCategory.attraction);
      expect(nearbyCategoryFor('lodging'), PlaceCategory.hotel);
      expect(nearbyCategoryFor('amusement_park'), PlaceCategory.amusementPark);
      expect(nearbyCategoryFor('beach'), PlaceCategory.beach);
      expect(nearbyCategoryFor('shopping_mall'), PlaceCategory.shopping);
      expect(nearbyCategoryFor('park'), PlaceCategory.nature);
    });

    test('an unmapped or null type is null, never a guess', () {
      expect(nearbyCategoryFor('gas_station'), isNull);
      expect(nearbyCategoryFor(null), isNull);
    });
  });

  group('filterAndSortNearbyResults', () {
    const lat = 13.7563;
    const lng = 100.5018;

    test('drops results below the rating/count threshold', () {
      final results = [
        _r('Too low rated', rating: 3.9),
        _r('Too few ratings', rating: 4.9, userRatingCount: 4),
        _r('Just enough', rating: 4.0, userRatingCount: 5),
      ];
      final kept = filterAndSortNearbyResults(results, lat: lat, lng: lng);
      expect(kept.map((r) => r.name).toList(), ['Just enough']);
    });

    test('sorts by rating descending, distance ascending as tiebreak', () {
      final results = [
        _r('Far, best rated', rating: 4.9, lat: 18.7883, lng: 98.9853),
        _r('Near, tied rating', rating: 4.5, lat: lat, lng: lng),
        _r('Far, tied rating', rating: 4.5, lat: 18.7883, lng: 98.9853),
      ];
      final sorted = filterAndSortNearbyResults(results, lat: lat, lng: lng);
      expect(sorted.map((r) => r.name).toList(), [
        'Far, best rated',
        'Near, tied rating',
        'Far, tied rating',
      ]);
    });

    test('empty input gives an empty list', () {
      expect(filterAndSortNearbyResults(const [], lat: lat, lng: lng), isEmpty);
    });
  });
}
