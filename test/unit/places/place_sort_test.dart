import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/domain/place_sort.dart';

Place _p(
  String name, {
  bool visited = false,
  DateTime? visitedAt,
  double? lat,
  double? lng,
}) =>
    Place(
      id: name,
      name: name,
      status: visited ? PlaceStatus.beenThere : PlaceStatus.wantToGo,
      visitedAt: visitedAt,
      lat: lat,
      lng: lng,
    );

void main() {
  group('comparePlacesRecommended', () {
    test('wishlist first (alphabetical), visited last (recent first)', () {
      final places = [
        _p('Zoo Negara', visited: true, visitedAt: DateTime(2026, 1, 1)),
        _p('Beach walk'),
        _p('Arun temple', visited: true, visitedAt: DateTime(2026, 6, 1)),
        _p('Aquarium'),
      ]..sort(comparePlacesRecommended);
      expect(places.map((p) => p.name).toList(), [
        'Aquarium',
        'Beach walk',
        'Arun temple',
        'Zoo Negara',
      ]);
    });

    test('visited without a date sorts last among visited', () {
      final places = [
        _p('No date', visited: true),
        _p('Dated', visited: true, visitedAt: DateTime(2026, 1, 1)),
      ]..sort(comparePlacesRecommended);
      expect(places.map((p) => p.name).toList(), ['Dated', 'No date']);
    });
  });

  group('comparePlacesByName', () {
    test('case-insensitive alphabetical', () {
      final places = [_p('zebra'), _p('Apple'), _p('mango')]
        ..sort(comparePlacesByName);
      expect(places.map((p) => p.name).toList(), ['Apple', 'mango', 'zebra']);
    });
  });

  group('comparePlacesByVisitedDate', () {
    test('ascending by visitedAt', () {
      final places = [
        _p('Later', visited: true, visitedAt: DateTime(2026, 6, 1)),
        _p('Earlier', visited: true, visitedAt: DateTime(2026, 1, 1)),
      ]..sort(comparePlacesByVisitedDate);
      expect(places.map((p) => p.name).toList(), ['Earlier', 'Later']);
    });
  });

  group('comparePlacesByDistance', () {
    // Bangkok as the device's current fix.
    const lat = 13.7563;
    const lng = 100.5018;

    test('nearest first', () {
      final places = [
        _p('Chiang Mai', lat: 18.7883, lng: 98.9853), // ~580km
        _p('Ayutthaya', lat: 14.3532, lng: 100.5686), // ~67km
        _p('Phuket', lat: 7.8804, lng: 98.3923), // ~680km
      ]..sort((a, b) => comparePlacesByDistance(a, b, lat: lat, lng: lng));
      expect(
        places.map((p) => p.name).toList(),
        ['Ayutthaya', 'Chiang Mai', 'Phuket'],
      );
    });

    test('a place at the fix itself sorts first', () {
      final places = [
        _p('Far', lat: 18.7883, lng: 98.9853),
        _p('Here', lat: lat, lng: lng),
      ]..sort((a, b) => comparePlacesByDistance(a, b, lat: lat, lng: lng));
      expect(places.map((p) => p.name).toList(), ['Here', 'Far']);
    });
  });

  group('placeDistanceFromKm', () {
    test('matches the haversine distance used for sorting', () {
      const lat = 13.7563;
      const lng = 100.5018;
      final ayutthaya = _p('Ayutthaya', lat: 14.3532, lng: 100.5686);
      expect(
        placeDistanceFromKm(ayutthaya, lat: lat, lng: lng),
        closeTo(67, 5),
      );
    });

    test('a place at the fix itself is ~0km away', () {
      const lat = 13.7563;
      const lng = 100.5018;
      final here = _p('Here', lat: lat, lng: lng);
      expect(placeDistanceFromKm(here, lat: lat, lng: lng), closeTo(0, 0.01));
    });
  });

  group('distanceBetweenKm', () {
    test('matches placeDistanceFromKm for the same two points', () {
      const lat = 13.7563;
      const lng = 100.5018;
      expect(
        distanceBetweenKm(lat1: lat, lng1: lng, lat2: 14.3532, lng2: 100.5686),
        closeTo(67, 5),
      );
    });

    test('the same point is ~0km away', () {
      expect(
        distanceBetweenKm(lat1: 1, lng1: 1, lat2: 1, lng2: 1),
        closeTo(0, 0.01),
      );
    });
  });
}
