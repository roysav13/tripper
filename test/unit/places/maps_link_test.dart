import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripper/core/sharing/maps_link.dart';

void main() {
  group('parseMapsShare', () {
    test('full place URL with @coords and name', () {
      final link = parseMapsShare(
        'https://www.google.com/maps/place/Railay+Beach/@8.0119,98.8378,15z',
      );
      expect(link, isNotNull);
      expect(link!.name, 'Railay Beach');
      expect(link.lat, closeTo(8.0119, 0.0001));
      expect(link.lng, closeTo(98.8378, 0.0001));
    });

    test('q=lat,lng URL', () {
      final link =
          parseMapsShare('https://maps.google.com/maps?q=41.8902,12.4922');
      expect(link!.hasCoordinates, isTrue);
      expect(link.lat, closeTo(41.8902, 0.0001));
    });

    test('short link keeps surrounding text as name guess', () {
      final link = parseMapsShare(
        'Colosseum https://maps.app.goo.gl/AbCdEf123',
      );
      expect(link, isNotNull);
      expect(link!.hasCoordinates, isFalse);
      expect(link.name, 'Colosseum');
      expect(isShortMapsLink(link.url), isTrue);
    });

    test('non-maps URLs and plain text return null', () {
      expect(parseMapsShare('https://example.com/foo'), isNull);
      expect(parseMapsShare('just some text'), isNull);
    });
  });

  group('MapsLinkService.expand', () {
    test('short link resolves through redirect to coordinates', () async {
      final client = MockClient.streaming((request, _) async {
        if (request.url.host == 'maps.app.goo.gl') {
          return http.StreamedResponse(
            const Stream.empty(),
            302,
            headers: {
              'location':
                  'https://www.google.com/maps/place/Colosseum/@41.8902,12.4922,17z',
            },
          );
        }
        return http.StreamedResponse(const Stream.empty(), 200);
      });
      final service = MapsLinkService(client);
      final link =
          await service.expand('Colosseum https://maps.app.goo.gl/AbC');
      expect(link!.hasCoordinates, isTrue);
      expect(link.name, 'Colosseum');
      expect(link.lat, closeTo(41.8902, 0.0001));
    });

    test('network failure falls back to partial parse (offline)', () async {
      final client = MockClient.streaming(
        (request, _) async => throw Exception('offline'),
      );
      final service = MapsLinkService(client);
      final link =
          await service.expand('Colosseum https://maps.app.goo.gl/AbC');
      expect(link, isNotNull);
      expect(link!.hasCoordinates, isFalse);
      expect(link.name, 'Colosseum');
    });
  });

  group('googleMapsUri', () {
    test('builds a maps.google.com search URL from coordinates', () {
      final uri = googleMapsUri(8.0119, 98.8378);
      expect(
        uri.toString(),
        'https://www.google.com/maps/search/?api=1&query=8.0119,98.8378',
      );
    });

    test('handles negative coordinates', () {
      final uri = googleMapsUri(-33.8688, 151.2093);
      expect(uri.queryParameters['query'], '-33.8688,151.2093');
    });
  });
}
