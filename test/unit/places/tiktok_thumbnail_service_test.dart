import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripper/features/places/data/tiktok_thumbnail_service.dart';

// A CDN that refuses the request often answers 200 with an HTML error page
// rather than an error status. Saving that as a `.jpg` only moves the
// failure to OCR, so the downloader rejects it up front.
void main() {
  group('HttpTikTokThumbnailDownloader rejects non-image bodies', () {
    test('200 with an HTML content-type is a failure, not a saved file',
        () async {
      final client = MockClient((request) async {
        return http.Response(
          '<!doctype html><title>Access denied</title>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });

      expect(
        await HttpTikTokThumbnailDownloader(client)
            .download('https://p16-common-sign.tiktokcdn.com/t.jpg'),
        isNull,
      );
    });

    test('a non-200 response is still a failure', () async {
      final client = MockClient((request) async => http.Response('', 403));

      expect(
        await HttpTikTokThumbnailDownloader(client)
            .download('https://p16-common-sign.tiktokcdn.com/t.jpg'),
        isNull,
      );
    });
  });

  group('HttpTikTokThumbnailDownloader sends the request', () {
    test('requests exactly the given thumbnail URL', () async {
      Uri? requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          'fake image bytes',
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      });

      await HttpTikTokThumbnailDownloader(client)
          .download('https://p16-common-sign.tiktokcdn.com/t.jpg?x=1');

      expect(
        requestedUri,
        Uri.parse('https://p16-common-sign.tiktokcdn.com/t.jpg?x=1'),
      );
    });
  });
}
