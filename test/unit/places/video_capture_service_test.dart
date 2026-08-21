import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripper/features/places/data/video_capture_service.dart';

// A CDN that refuses the request often answers 200 with an HTML or JSON
// error page rather than an error status. Saving that as a `.mp4` only
// moves the failure to `VideoPlayerController.initialize()`, where the user
// sees a broken player instead of "couldn't fetch this video" — so the
// downloader rejects it up front.
void main() {
  group('HttpVideoDownloader rejects non-video bodies', () {
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
        await HttpVideoDownloader(client)
            .download(Uri.parse('https://cdn.example.com/v.mp4')),
        isNull,
      );
    });

    test('200 with a JSON error body is a failure too', () async {
      final client = MockClient((request) async {
        return http.Response(
          '{"error":"expired signature"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      expect(
        await HttpVideoDownloader(client)
            .download(Uri.parse('https://cdn.example.com/v.mp4')),
        isNull,
      );
    });

    test('a non-200 response is still a failure', () async {
      final client = MockClient((request) async => http.Response('', 403));

      expect(
        await HttpVideoDownloader(client)
            .download(Uri.parse('https://cdn.example.com/v.mp4')),
        isNull,
      );
    });
  });

  group('HttpVideoDownloader sends anti-hotlinking headers', () {
    test('every request carries a User-Agent and a Referer', () async {
      Map<String, String>? capturedHeaders;
      final client = MockClient((request) async {
        capturedHeaders = request.headers;
        return http.Response(
          'fake video bytes',
          200,
          headers: {'content-type': 'video/mp4'},
        );
      });

      await HttpVideoDownloader(client)
          .download(Uri.parse('https://cdn.example.com/v.mp4'));

      expect(capturedHeaders, isNotNull);
      expect(capturedHeaders!['User-Agent'], isNotEmpty);
      expect(capturedHeaders!['Referer'], 'https://www.tiktok.com/');
    });
  });
}
