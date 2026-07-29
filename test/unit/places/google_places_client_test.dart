import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripper/features/places/data/geocoding_service.dart';
import 'package:tripper/features/places/data/google_places_geocoder.dart';

// These exercise the exception *reason* (diagnostic-only, never shown to
// the user) that each failure mode produces, so a misconfigured API key
// prints something a developer can act on instead of a bare "offline".
void main() {
  group('GooglePlacesGeocoder surfaces the real failure', () {
    test('REQUEST_DENIED (e.g. Android-restricted key) is not "unknown"',
        () async {
      final client = MockClient((request) async {
        return http.Response(
          '{"error": {"status": "PERMISSION_DENIED", '
          '"message": "API key not authorized for this API or the request '
          'is missing app identification headers."}}',
          403,
        );
      });
      final geocoder = GooglePlacesGeocoder(client, apiKey: 'test-key');

      await expectLater(
        () => geocoder.search('Rome'),
        throwsA(
          isA<GeocodingException>().having(
            (e) => e.reason,
            'reason',
            allOf(contains('403'), contains('PERMISSION_DENIED')),
          ),
        ),
      );
    });

    test('API not enabled surfaces the status code and body', () async {
      final client = MockClient((request) async {
        return http.Response(
          '{"error": {"status": "INVALID_ARGUMENT", '
          '"message": "Places API (New) has not been used in this project"}}',
          400,
        );
      });
      final geocoder = GooglePlacesGeocoder(client, apiKey: 'test-key');

      await expectLater(
        () => geocoder.search('Rome'),
        throwsA(
          isA<GeocodingException>().having(
            (e) => e.reason,
            'reason',
            contains('has not been used in this project'),
          ),
        ),
      );
    });

    test('transport failure (no network) surfaces the exception, not silence',
        () async {
      final client = MockClient((request) async {
        throw const SocketExceptionStub();
      });
      final geocoder = GooglePlacesGeocoder(client, apiKey: 'test-key');

      await expectLater(
        () => geocoder.search('Rome'),
        throwsA(
          isA<GeocodingException>()
              .having((e) => e.reason, 'reason', contains('SocketException')),
        ),
      );
    });

    test('successful response still parses normally', () async {
      final client = MockClient((request) async {
        return http.Response(
          '{"suggestions": [{"placePrediction": {"placeId": "abc", '
          '"text": {"text": "Rome, Italy"}}}]}',
          200,
        );
      });
      final geocoder = GooglePlacesGeocoder(client, apiKey: 'test-key');
      final results = await geocoder.search('Rome');
      expect(results, hasLength(1));
      expect(results.single.placeId, 'abc');
    });
  });
}

/// Stand-in for dart:io's SocketException so this test has no platform
/// dependency — only its runtime type name matters for the reason string.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'SocketException: Failed host lookup';
}
