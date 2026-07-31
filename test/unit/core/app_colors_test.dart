import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_colors.dart';

void main() {
  group('AppColors.tripAccent', () {
    test('indexes straight into tripPalette for in-range tags', () {
      for (final theme in [AppColors.light, AppColors.dark]) {
        for (var i = 0; i < theme.tripPalette.length; i++) {
          expect(theme.tripAccent(i), theme.tripPalette[i]);
        }
      }
    });

    test('wraps out-of-range colorTag values instead of throwing', () {
      final theme = AppColors.light;
      final len = theme.tripPalette.length;
      expect(theme.tripAccent(len), theme.tripPalette[0]);
      expect(theme.tripAccent(len + 3), theme.tripPalette[3]);
      // Old/negative data (shouldn't occur, but must never crash a trip
      // card render).
      expect(() => theme.tripAccent(1000), returnsNormally);
    });
  });

  group('trip palette vs. semantic colors', () {
    test('no trip tag color collides with warning/error/success', () {
      for (final theme in [AppColors.light, AppColors.dark]) {
        final semantic = {theme.warning, theme.error, theme.success};
        for (final tripColor in theme.tripPalette) {
          expect(
            semantic.contains(tripColor),
            isFalse,
            reason: 'A trip identity color must never equal a semantic color, '
                'or a colored trip tag could be misread as a warning.',
          );
        }
      }
    });

    test('light and dark palettes have the same length and ordering', () {
      // Trip.colorTag is a stored index — reordering or resizing either
      // palette would silently re-color every saved trip.
      expect(AppColors.light.tripPalette.length, 8);
      expect(
        AppColors.dark.tripPalette.length,
        AppColors.light.tripPalette.length,
      );
    });
  });

  group('AppColors.onColor', () {
    test('picks ink for a pale trip color and paper-surface for a dark one',
        () {
      final theme = AppColors.light;
      // Marigold is the palette's lightest/most luminant hue.
      final marigold = theme.tripPalette[1];
      expect(theme.onColor(marigold), theme.inkPrimary);
      // Harbor teal is dark/saturated.
      final teal = theme.tripPalette[0];
      expect(theme.onColor(teal), theme.surface);
    });

    test('always returns one of the two designed ink/surface tones', () {
      final theme = AppColors.light;
      for (final color in theme.tripPalette) {
        final resolved = theme.onColor(color);
        expect(
          resolved == theme.inkPrimary || resolved == theme.surface,
          isTrue,
        );
      }
    });
  });
}
