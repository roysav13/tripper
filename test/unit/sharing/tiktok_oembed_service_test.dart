import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripper/core/sharing/tiktok_oembed_service.dart';

// Trimmed shape of a real TikTok oEmbed response (fields this app reads;
// `html` and other embed-widget fields are omitted as noise).
const _realShapedBody = '''
{
  "version": "1.0",
  "type": "video",
  "title": "Leave it up to me to find the hidden gems, East Java #eastjava",
  "author_url": "https://www.tiktok.com/@jamie.fisch",
  "author_name": "Jamie | Travel & Adventure",
  "thumbnail_url": "https://p16-common-sign.tiktokcdn.com/tos-useast8-p-0068-tx2/abc~tplv-tiktokx-origin.image?x-expires=1787515200&x-signature=abc",
  "thumbnail_width": 720,
  "thumbnail_height": 1280
}
''';

void main() {
  group('parseTikTokOEmbed', () {
    test('reads caption and thumbnail off a real-shaped response', () {
      final result = parseTikTokOEmbed(_realShapedBody);
      expect(result, isNotNull);
      expect(result!.caption, contains('East Java'));
      expect(
        result.thumbnailUrl,
        'https://p16-common-sign.tiktokcdn.com/tos-useast8-p-0068-tx2/abc~tplv-tiktokx-origin.image?x-expires=1787515200&x-signature=abc',
      );
    });

    test('thumbnail-only response (no caption) still parses', () {
      const body = '{"thumbnail_url": "https://example.com/t.jpg"}';
      final result = parseTikTokOEmbed(body);
      expect(result, isNotNull);
      expect(result!.caption, isNull);
      expect(result.thumbnailUrl, 'https://example.com/t.jpg');
    });

    test('caption-only response (no thumbnail) still parses', () {
      const body = '{"title": "A great trip"}';
      final result = parseTikTokOEmbed(body);
      expect(result, isNotNull);
      expect(result!.caption, 'A great trip');
      expect(result.thumbnailUrl, isNull);
    });

    test('blank/whitespace-only fields are treated as absent', () {
      const body = '{"title": "   ", "thumbnail_url": ""}';
      expect(parseTikTokOEmbed(body), isNull);
    });

    test('neither field present yields null', () {
      expect(parseTikTokOEmbed('{"version": "1.0"}'), isNull);
    });

    test('garbage input never throws', () {
      expect(parseTikTokOEmbed('not json'), isNull);
      expect(parseTikTokOEmbed('[]'), isNull);
      expect(parseTikTokOEmbed(''), isNull);
    });
  });

  group('HttpTikTokOEmbedFetcher.fetch', () {
    test('non-TikTok text yields null without any network call', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('', 200);
      });

      expect(await HttpTikTokOEmbedFetcher(client).fetch('no link here'), isNull);
      expect(called, isFalse);
    });

    test('requests the oembed endpoint with the shared URL and parses the '
        'response', () async {
      Uri? requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(_realShapedBody, 200);
      });

      final result = await HttpTikTokOEmbedFetcher(client)
          .fetch('https://www.tiktok.com/@jamie.fisch/video/123');

      expect(requestedUri, isNotNull);
      expect(requestedUri!.host, 'www.tiktok.com');
      expect(requestedUri!.path, '/oembed');
      expect(
        requestedUri!.queryParameters['url'],
        'https://www.tiktok.com/@jamie.fisch/video/123',
      );
      expect(result, isNotNull);
      expect(result!.caption, contains('East Java'));
    });

    test('non-200 response degrades to null, never throws', () async {
      final client = MockClient((request) async => http.Response('', 404));

      expect(
        await HttpTikTokOEmbedFetcher(client)
            .fetch('https://www.tiktok.com/@u/video/1'),
        isNull,
      );
    });

    test('transport failure degrades to null, never throws', () async {
      final client = MockClient((request) async => throw Exception('down'));

      expect(
        await HttpTikTokOEmbedFetcher(client)
            .fetch('https://www.tiktok.com/@u/video/1'),
        isNull,
      );
    });
  });
}
