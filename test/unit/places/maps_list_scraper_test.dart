import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/sharing/maps_list_scraper.dart';

void main() {
  group('cleanScrapedListTitle', () {
    test('strips the Google Maps suffix', () {
      expect(cleanScrapedListTitle('Japan - Google Maps'), 'Japan');
    });

    test('returns the title unchanged when there is no suffix', () {
      expect(cleanScrapedListTitle('Japan'), 'Japan');
    });

    test('null input returns null', () {
      expect(cleanScrapedListTitle(null), isNull);
    });

    test('empty or suffix-only title returns null', () {
      expect(cleanScrapedListTitle(''), isNull);
      expect(cleanScrapedListTitle(' - Google Maps'), isNull);
    });
  });
}
