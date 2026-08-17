import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/nearby_place.dart';
import 'geocoding_service.dart';

/// Fixed radius, no picker in v1 (design decision, easy follow-up).
const _nearbyRadiusMeters = 2000.0;
const _nearbyMaxResults = 20;

/// Widget/unit tests fake at this boundary.
abstract interface class NearbyPlacesFetcher {
  Future<List<NearbyPlaceResult>> searchNearby({
    required double lat,
    required double lng,
  });
}

/// Google Places API (New) `searchNearby` — same client, exception, and
/// timeout conventions as `GooglePlacesGeocoder`. A minimal field mask
/// keeps this in the cheapest SKU tier; no `includedTypes` restriction
/// (all types together, per the approved design).
class GoogleNearbyPlacesFetcher implements NearbyPlacesFetcher {
  GoogleNearbyPlacesFetcher(this._client, {required String apiKey})
      : _apiKey = apiKey;

  final http.Client _client;
  final String _apiKey;

  @override
  Future<List<NearbyPlaceResult>> searchNearby({
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.https('places.googleapis.com', '/v1/places:searchNearby'),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _apiKey,
              'X-Goog-FieldMask': 'places.id,places.displayName,'
                  'places.location,places.rating,places.userRatingCount,'
                  'places.primaryType',
            },
            body: jsonEncode({
              'maxResultCount': _nearbyMaxResults,
              'locationRestriction': {
                'circle': {
                  'center': {'latitude': lat, 'longitude': lng},
                  'radius': _nearbyRadiusMeters,
                },
              },
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw GeocodingException(
          'Nearby search HTTP ${response.statusCode}: '
          '${_truncate(response.body)}',
        );
      }
      return parseSearchNearby(response.body);
    } on GeocodingException {
      rethrow;
    } catch (e) {
      throw GeocodingException('Nearby search $e');
    }
  }
}

/// Keeps debug-console noise down when an API error body is a wall of JSON.
String _truncate(String body, [int max = 300]) =>
    body.length <= max ? body : '${body.substring(0, max)}…';

/// Pure parser — unit-tested against fixture JSON, no network. Skips any
/// entry missing an id, a usable location, or a name — never a guess.
List<NearbyPlaceResult> parseSearchNearby(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) return const [];
  final places = decoded['places'];
  if (places is! List) return const [];
  final results = <NearbyPlaceResult>[];
  for (final p in places) {
    if (p is! Map<String, dynamic>) continue;
    final id = p['id']?.toString();
    if (id == null || id.isEmpty) continue;
    final location = p['location'];
    if (location is! Map) continue;
    final lat = (location['latitude'] as num?)?.toDouble();
    final lng = (location['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) continue;
    final displayName = p['displayName'];
    final name = displayName is Map ? displayName['text']?.toString() : null;
    if (name == null || name.isEmpty) continue;
    results.add(
      NearbyPlaceResult(
        placeId: id,
        name: name,
        lat: lat,
        lng: lng,
        rating: (p['rating'] as num?)?.toDouble() ?? 0,
        userRatingCount: (p['userRatingCount'] as num?)?.toInt() ?? 0,
        primaryType: p['primaryType']?.toString(),
      ),
    );
  }
  return results;
}
