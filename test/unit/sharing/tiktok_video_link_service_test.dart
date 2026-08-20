import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripper/core/sharing/tiktok_video_link_service.dart';

String _pageWithVideo(String playAddr) {
  final json = jsonEncode({
    'default-scope': {
      'webapp.video-detail': {
        'itemInfo': {
          'itemStruct': {
            'video': {'playAddr': playAddr},
          },
        },
      },
    },
  });
  return '<html><body>'
      '<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">'
      '$json'
      '</script>'
      '</body></html>';
}

void main() {
  group('extractTikTokVideoUrl', () {
    test('finds playAddr nested in the rehydration JSON', () {
      final html = _pageWithVideo('https://v.tiktokcdn.com/abc.mp4');
      expect(
        extractTikTokVideoUrl(html),
        'https://v.tiktokcdn.com/abc.mp4',
      );
    });

    test('unescapes \\u002F-encoded slashes', () {
      const html = '<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" '
          'type="application/json">'
          '{"video":{"playAddr":"https:\\u002F\\u002Fv.tiktokcdn.com\\u002Fabc.mp4"}}'
          '</script>';
      expect(
        extractTikTokVideoUrl(html),
        'https://v.tiktokcdn.com/abc.mp4',
      );
    });

    test('missing script tag yields null', () {
      expect(extractTikTokVideoUrl('<html><body>nothing here</body></html>'),
          isNull);
    });

    test('malformed JSON yields null, never throws', () {
      const html = '<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" '
          'type="application/json">{not json</script>';
      expect(extractTikTokVideoUrl(html), isNull);
    });

    test('JSON with no playAddr/downloadAddr field yields null', () {
      const html = '<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" '
          'type="application/json">{"foo":"bar"}</script>';
      expect(extractTikTokVideoUrl(html), isNull);
    });

    test('falls back to downloadAddr when playAddr is absent', () {
      const html = '<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" '
          'type="application/json">'
          '{"video":{"downloadAddr":"https://v.tiktokcdn.com/dl.mp4"}}'
          '</script>';
      expect(extractTikTokVideoUrl(html), 'https://v.tiktokcdn.com/dl.mp4');
    });
  });

  group('TikTokVideoLinkService.resolveVideoUrl', () {
    test('follows a short-link redirect then extracts the video URL',
        () async {
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.host == 'vt.tiktok.com') {
          return http.Response(
            '',
            302,
            headers: {
              'location': 'https://www.tiktok.com/@user/video/12345',
            },
          );
        }
        if (request.url.host == 'www.tiktok.com') {
          return http.Response(_pageWithVideo('https://v.tiktokcdn.com/x.mp4'),
              200);
        }
        return http.Response('', 404);
      });
      final service = TikTokVideoLinkService(client);

      final result =
          await service.resolveVideoUrl('https://vt.tiktok.com/ZS6abcDEF/');

      expect(result, Uri.parse('https://v.tiktokcdn.com/x.mp4'));
    });

    test('non-TikTok text yields null without any network call', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('', 200);
      });
      final service = TikTokVideoLinkService(client);

      expect(await service.resolveVideoUrl('no link here'), isNull);
      expect(called, isFalse);
    });

    test('page fetch failure degrades to null, never throws', () async {
      final client = MockClient((request) async => http.Response('', 500));
      final service = TikTokVideoLinkService(client);

      expect(
        await service.resolveVideoUrl('https://www.tiktok.com/@u/video/1'),
        isNull,
      );
    });

    test('transport failure degrades to null, never throws', () async {
      final client = MockClient((request) async => throw Exception('down'));
      final service = TikTokVideoLinkService(client);

      expect(
        await service.resolveVideoUrl('https://www.tiktok.com/@u/video/1'),
        isNull,
      );
    });

    test('page with no extractable video yields null', () async {
      final client = MockClient(
        (request) async => http.Response('<html></html>', 200),
      );
      final service = TikTokVideoLinkService(client);

      expect(
        await service.resolveVideoUrl('https://www.tiktok.com/@u/video/1'),
        isNull,
      );
    });
  });
}
