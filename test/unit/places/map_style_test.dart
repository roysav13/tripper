import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/places/presentation/map_style.dart';

void main() {
  group('map styles', () {
    test('both styles are valid JSON', () {
      expect(jsonDecode(kMapStyleLight), isA<List<dynamic>>());
      expect(jsonDecode(kMapStyleDark), isA<List<dynamic>>());
    });

    test(
        'light style is authored from AppColors.light.mapWater/mapLand, '
        'not left as Google\'s default (null) tiles', () {
      expect(kMapStyleLight, contains('#dceae6')); // mapWater (light)
      expect(kMapStyleLight, contains('#efe7d8')); // mapLand (light)
    });

    test(
        'dark style is retuned to AppColors.dark.mapWater/mapLand, not '
        'Google\'s generic Night style', () {
      expect(kMapStyleDark, contains('#17263c')); // mapWater (dark)
      expect(kMapStyleDark, contains('#242f3e')); // mapLand (dark)
    });

    test(
        'dark style reuses warning.amber for labels, not Google\'s '
        'default gold', () {
      expect(kMapStyleDark, contains('#f2a93c')); // warning.amber (dark)
      expect(kMapStyleDark, isNot(contains('#d59563')));
      expect(kMapStyleDark, isNot(contains('#f3d19c')));
    });
  });
}
