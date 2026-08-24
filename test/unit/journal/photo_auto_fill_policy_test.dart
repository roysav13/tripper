import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/journal/data/journal_photo_exif.dart';
import 'package:tripper/features/journal/domain/photo_auto_fill_policy.dart';

void main() {
  group('PhotoAutoFillPolicy', () {
    test('a photo with both time and location fills both, and is done',
        () {
      final policy = PhotoAutoFillPolicy();

      final result = policy.consider(
        PhotoExifData(takenAt: DateTime(2024, 6, 1, 9), lat: 8.0, lng: 98.8),
      );

      expect(result, isNotNull);
      expect(result!.loggedAt, DateTime(2024, 6, 1, 9));
      expect(result.lat, 8.0);
      expect(result.lng, 98.8);
      expect(policy.done, isTrue);
    });

    test('a photo with only a location fills only the location', () {
      final policy = PhotoAutoFillPolicy();

      final result = policy.consider(
        const PhotoExifData(lat: 8.0, lng: 98.8),
      );

      expect(result!.loggedAt, isNull);
      expect(result.lat, 8.0);
      expect(result.lng, 98.8);
      expect(policy.done, isTrue);
    });

    test('a photo with only a time fills only the time', () {
      final policy = PhotoAutoFillPolicy();

      final result = policy.consider(
        PhotoExifData(takenAt: DateTime(2024, 6, 1, 9)),
      );

      expect(result!.loggedAt, DateTime(2024, 6, 1, 9));
      expect(result.lat, isNull);
      expect(result.lng, isNull);
      expect(policy.done, isTrue);
    });

    test('a photo with neither leaves the policy open for the next photo',
        () {
      final policy = PhotoAutoFillPolicy();

      final result = policy.consider(const PhotoExifData());

      expect(result, isNull);
      expect(policy.done, isFalse);
    });

    test('once done, a later photo with EXIF data is never applied', () {
      final policy = PhotoAutoFillPolicy();
      policy.consider(PhotoExifData(takenAt: DateTime(2024, 6, 1, 9)));

      final second = policy.consider(
        const PhotoExifData(lat: 1, lng: 2),
      );

      expect(second, isNull);
      expect(policy.done, isTrue);
    });

    test('a field the user already touched is never overwritten', () {
      final policy = PhotoAutoFillPolicy()..loggedAtTouched = true;

      final result = policy.consider(
        PhotoExifData(
          takenAt: DateTime(2024, 6, 1, 9),
          lat: 8.0,
          lng: 98.8,
        ),
      );

      expect(result!.loggedAt, isNull);
      expect(result.lat, 8.0);
      expect(result.lng, 98.8);
    });

    test(
        'a photo whose only info is a touched field yields null and stays '
        'open for the next photo', () {
      final policy = PhotoAutoFillPolicy()..locationTouched = true;

      final result = policy.consider(const PhotoExifData(lat: 8.0, lng: 98.8));

      expect(result, isNull);
      expect(policy.done, isFalse);
    });
  });
}
