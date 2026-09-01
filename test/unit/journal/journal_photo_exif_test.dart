import 'package:exif/exif.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/journal/data/journal_photo_exif.dart';

IfdTag _ratios(List<Ratio> values) => IfdTag(
      tag: 0,
      tagType: 'R',
      printable: values.join(', '),
      values: IfdRatios(values),
    );

IfdTag _ascii(String printable) => IfdTag(
      tag: 0,
      tagType: 'A',
      printable: printable,
      values: const IfdNone(),
    );

void main() {
  group('extractGpsCoordinates', () {
    test('reads a northern/eastern hemisphere fix as positive lat/lng', () {
      final tags = {
        'GPS GPSLatitude':
            _ratios([Ratio(8, 1), Ratio(0, 1), Ratio(2840, 100)]),
        'GPS GPSLatitudeRef': _ascii('N'),
        'GPS GPSLongitude':
            _ratios([Ratio(98, 1), Ratio(50, 1), Ratio(1210, 100)]),
        'GPS GPSLongitudeRef': _ascii('E'),
      };

      final result = extractGpsCoordinates(tags);

      expect(result, isNotNull);
      expect(result!.lat, closeTo(8.007889, 1e-6));
      expect(result.lng, closeTo(98.836694, 1e-6));
    });

    test('southern/western hemisphere refs negate the decimal degrees', () {
      final tags = {
        'GPS GPSLatitude': _ratios([Ratio(33, 1), Ratio(51, 1), Ratio(0, 1)]),
        'GPS GPSLatitudeRef': _ascii('S'),
        'GPS GPSLongitude': _ratios([Ratio(151, 1), Ratio(12, 1), Ratio(0, 1)]),
        'GPS GPSLongitudeRef': _ascii('W'),
      };

      final result = extractGpsCoordinates(tags);

      expect(result!.lat, closeTo(-33.85, 1e-9));
      expect(result.lng, closeTo(-151.2, 1e-9));
    });

    test('missing GPS tags yields null', () {
      expect(extractGpsCoordinates(const {}), isNull);
    });

    test('a photo with only some of the four GPS tags yields null', () {
      final tags = {
        'GPS GPSLatitude': _ratios([Ratio(8, 1), Ratio(0, 1), Ratio(0, 1)]),
        'GPS GPSLatitudeRef': _ascii('N'),
      };
      expect(extractGpsCoordinates(tags), isNull);
    });

    test('malformed values (not ratios) yields null, never throws', () {
      final tags = {
        'GPS GPSLatitude': IfdTag(
          tag: 0,
          tagType: 'X',
          printable: 'garbage',
          values: const IfdInts([1, 2, 3]),
        ),
        'GPS GPSLatitudeRef': _ascii('N'),
        'GPS GPSLongitude': _ratios([Ratio(98, 1), Ratio(50, 1), Ratio(0, 1)]),
        'GPS GPSLongitudeRef': _ascii('E'),
      };
      expect(extractGpsCoordinates(tags), isNull);
    });
  });

  group('extractPhotoTakenAt', () {
    test('reads EXIF DateTimeOriginal in its standard colon-separated form',
        () {
      final tags = {
        'EXIF DateTimeOriginal': _ascii('2024:06:01 14:23:05'),
      };

      final result = extractPhotoTakenAt(tags);

      expect(result, DateTime(2024, 6, 1, 14, 23, 5));
    });

    test('falls back to Image DateTime when DateTimeOriginal is absent', () {
      final tags = {
        'Image DateTime': _ascii('2023:01:15 08:00:00'),
      };

      final result = extractPhotoTakenAt(tags);

      expect(result, DateTime(2023, 1, 15, 8, 0, 0));
    });

    test('DateTimeOriginal takes priority over Image DateTime', () {
      final tags = {
        'EXIF DateTimeOriginal': _ascii('2024:06:01 14:23:05'),
        'Image DateTime': _ascii('2023:01:15 08:00:00'),
      };

      expect(extractPhotoTakenAt(tags), DateTime(2024, 6, 1, 14, 23, 5));
    });

    test('missing time tags yields null', () {
      expect(extractPhotoTakenAt(const {}), isNull);
    });

    test('an unparsable date string yields null, never throws', () {
      final tags = {'EXIF DateTimeOriginal': _ascii('not a date')};
      expect(extractPhotoTakenAt(tags), isNull);
    });
  });
}
