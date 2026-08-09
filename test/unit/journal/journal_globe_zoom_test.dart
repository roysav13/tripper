import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/journal/presentation/journal_globe.dart';

void main() {
  group('shouldRequestHighResGlobeSurface', () {
    test('false below the threshold', () {
      expect(
        shouldRequestHighResGlobeSurface(zoom: 1.0, alreadyRequested: false),
        isFalse,
      );
    });

    test('false exactly at the threshold', () {
      expect(
        shouldRequestHighResGlobeSurface(
          zoom: highResGlobeZoomThreshold,
          alreadyRequested: false,
        ),
        isFalse,
      );
    });

    test('true just above the threshold, not yet requested', () {
      expect(
        shouldRequestHighResGlobeSurface(
          zoom: highResGlobeZoomThreshold + 0.1,
          alreadyRequested: false,
        ),
        isTrue,
      );
    });

    test('false above the threshold if already requested', () {
      expect(
        shouldRequestHighResGlobeSurface(
          zoom: highResGlobeZoomThreshold + 0.1,
          alreadyRequested: true,
        ),
        isFalse,
      );
    });

    test('false well above the threshold if already requested', () {
      expect(
        shouldRequestHighResGlobeSurface(zoom: 3.5, alreadyRequested: true),
        isFalse,
      );
    });
  });
}
