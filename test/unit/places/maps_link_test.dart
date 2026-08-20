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

  group('isMapsListShareUrl', () {
    test('matches a real captured list-share redirect target', () {
      expect(
        isMapsListShareUrl(
          'https://www.google.com/maps/@/data=!3m1!4b1!4m3!11m2'
          '!2sTAO99XYR4fuhOSQo1zrQ0Tit84j9Qw!3e3?entry=tts',
        ),
        isTrue,
      );
    });

    test('a single-place URL is not a list', () {
      expect(
        isMapsListShareUrl(
          'https://www.google.com/maps/place/Colosseum/@41.8902,12.4922,17z',
        ),
        isFalse,
      );
    });

    test('a non-maps URL is not a list', () {
      expect(isMapsListShareUrl('https://example.com/maps/@/data=x'), isFalse);
    });

    test('an unparseable URL is not a list', () {
      expect(isMapsListShareUrl('not a url at all'), isFalse);
    });
  });

  group('MapsLinkService.expand — place shares', () {
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
      final result =
          await service.expand('Colosseum https://maps.app.goo.gl/AbC');
      final share = result as MapsPlaceShare;
      expect(share.link.hasCoordinates, isTrue);
      expect(share.link.name, 'Colosseum');
      expect(share.link.lat, closeTo(41.8902, 0.0001));
    });

    test('network failure falls back to partial parse (offline)', () async {
      final client = MockClient.streaming(
        (request, _) async => throw Exception('offline'),
      );
      final service = MapsLinkService(client);
      final result =
          await service.expand('Colosseum https://maps.app.goo.gl/AbC');
      expect(result, isNotNull);
      final share = result as MapsPlaceShare;
      expect(share.link.hasCoordinates, isFalse);
      expect(share.link.name, 'Colosseum');
    });

    test('a full (non-short) URL never touches the network', () async {
      final client = MockClient.streaming(
        (request, _) async => fail('unexpected request to ${request.url}'),
      );
      final service = MapsLinkService(client);
      final result = await service.expand(
        'https://www.google.com/maps/place/Colosseum/@41.8902,12.4922,17z',
      );
      final share = result as MapsPlaceShare;
      expect(share.link.hasCoordinates, isTrue);
    });
  });

  group('MapsLinkService.expand — list shares', () {
    test('a directly-pasted list URL returns MapsListShare, no network call',
        () async {
      final client = MockClient.streaming(
        (request, _) async => fail('unexpected request to ${request.url}'),
      );
      final service = MapsLinkService(client);
      final result = await service.expand(
        'Japan https://www.google.com/maps/@/data=!3m1!4b1!4m3!11m2'
        '!2sTAO99XYR4fuhOSQo1zrQ0Tit84j9Qw!3e3',
      );
      expect(result, isA<MapsListShare>());
      final share = result as MapsListShare;
      expect(share.url, contains('!11m2!2sTAO99XYR4fuhOSQo1zrQ0Tit84j9Qw!3e3'));
      expect(share.nameGuess, 'Japan');
    });

    test(
        'a short link resolving to a list-share URL returns MapsListShare '
        'without fetching the resolved page body', () async {
      final client = MockClient.streaming((request, _) async {
        if (request.url.host == 'maps.app.goo.gl') {
          return http.StreamedResponse(
            const Stream.empty(),
            302,
            headers: {
              'location': 'https://www.google.com/maps/@/data=!3m1!4b1!4m3'
                  '!11m2!2sTAO99XYR4fuhOSQo1zrQ0Tit84j9Qw!3e3?entry=tts',
            },
          );
        }
        fail('unexpected second request to ${request.url}');
      });
      final service = MapsLinkService(client);
      final result = await service
          .expand('Japan https://maps.app.goo.gl/gSpd52y9RYFDAspHA');
      expect(result, isA<MapsListShare>());
      final share = result as MapsListShare;
      expect(share.url, contains('!11m2!2sTAO99XYR4fuhOSQo1zrQ0Tit84j9Qw!3e3'));
      expect(share.nameGuess, 'Japan');
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
