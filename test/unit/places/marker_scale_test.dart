import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/places/presentation/places_map_view.dart';

void main() {
  group('markerScaleForZoom', () {
    test('world/continent zoom draws the smallest dots', () {
      expect(markerScaleForZoom(2), 0.5);
      expect(markerScaleForZoom(4), 0.5);
    });

    test('country zoom is a middle tier', () {
      expect(markerScaleForZoom(5), 0.65);
      expect(markerScaleForZoom(7), 0.65);
    });

    test('region zoom is another middle tier', () {
      expect(markerScaleForZoom(8), 0.8);
      expect(markerScaleForZoom(10), 0.8);
    });

    test('city zoom is near full size', () {
      expect(markerScaleForZoom(11), 0.9);
      expect(markerScaleForZoom(13), 0.9);
    });

    test('street zoom and closer draws full-size dots', () {
      expect(markerScaleForZoom(14), 1.0);
      expect(markerScaleForZoom(20), 1.0);
    });

    test('scale never exceeds 1.0 or drops below 0.5', () {
      for (var zoom = 0.0; zoom <= 21.0; zoom += 0.5) {
        final scale = markerScaleForZoom(zoom);
        expect(scale, greaterThanOrEqualTo(0.5));
        expect(scale, lessThanOrEqualTo(1.0));
      }
    });
  });
}
