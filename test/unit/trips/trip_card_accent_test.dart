import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_colors.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/trips/presentation/trip_card.dart';

Trip _trip(int colorTag) => Trip(
      id: 't',
      name: 'Test',
      destinations: const ['Somewhere'],
      colorTag: colorTag,
    );

void main() {
  group('tripCardAccent', () {
    test('non-past statuses use the raw trip color, unfaded', () {
      final colors = AppColors.light;
      final trip = _trip(3);
      for (final status in [
        TripStatus.active,
        TripStatus.upcoming,
        TripStatus.planned,
      ]) {
        expect(
          tripCardAccent(colors, trip, status),
          colors.tripPalette[3],
          reason: '$status should not fade the identity color',
        );
      }
    });

    test('a past trip fades its color toward paper', () {
      final colors = AppColors.light;
      final trip = _trip(3);
      final faded = tripCardAccent(colors, trip, TripStatus.past);

      // Faded toward paper, but a 0.6 lerp keeps it recognizably tinted —
      // neither the original saturated color nor plain paper.
      expect(faded, isNot(colors.tripPalette[3]));
      expect(faded, isNot(colors.paper));
    });

    test('the fade is deterministic for the same inputs', () {
      final colors = AppColors.light;
      final trip = _trip(5);
      expect(
        tripCardAccent(colors, trip, TripStatus.past),
        tripCardAccent(colors, trip, TripStatus.past),
      );
    });
  });
}
