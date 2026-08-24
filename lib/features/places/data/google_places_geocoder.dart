import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'geocoding_service.dart';

/// Key comes from --dart-define (see tool/run.ps1); empty means "not
/// configured", and the caller falls back to Nominatim.
const kGoogleMapsApiKey = String.fromEnvironment('MAPS_API_KEY');

/// Wraps [kGoogleMapsApiKey] behind a provider so widget tests can
/// simulate "a Maps key is configured" without a real `--dart-define`
/// (mirrors how every other network-capability gate in this app is an
/// overridable provider, not a raw constant read directly by a widget).
final mapsApiKeyConfiguredProvider =
    Provider<bool>((ref) => kGoogleMapsApiKey.isNotEmpty);

/// Places API (New). Autocomplete + Place Details, English-forced.
///
/// Autocomplete is billed per session, not per keystroke: one session token
/// covers all typing plus the final Details call, so a search costs one
/// session however many characters were typed. Combined with the 500ms
/// debounce, a personal app stays deep inside the free tier.
class GooglePlacesGeocoder implements Geocoder {
  GooglePlacesGeocoder(
    this._client, {
    required String apiKey,
    Future<void> Function()? onRealFetch,
  })  : _apiKey = apiKey,
        _onRealFetch = onRealFetch ?? (() async {});

  final http.Client _client;
  final String _apiKey;
  final Future<void> Function() _onRealFetch;
  final _uuid = const Uuid();

  String? _sessionToken;

  Map<String, String> _headers(String fieldMask) => {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask': fieldMask,
      };

  @override
  Future<List<GeoResult>> search(String query) async {
    // One token spans the whole typing session; cleared once Details runs.
    _sessionToken ??= _uuid.v4();
    try {
      final response = await _client
          .post(
            Uri.https('places.googleapis.com', '/v1/places:autocomplete'),
            headers: _headers(
              'suggestions.placePrediction.placeId,'
              'suggestions.placePrediction.text,'
              'suggestions.placePrediction.structuredFormat',
            ),
            body: jsonEncode({
              'input': query,
              'languageCode': 'en',
              'sessionToken': _sessionToken,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw GeocodingException(
          'Places autocomplete HTTP ${response.statusCode}: '
          '${_truncateBody(response.body)}',
        );
      }
      await _onRealFetch();
      return parseGooglePredictions(response.body);
    } on GeocodingException {
      rethrow;
    } catch (e) {
      throw GeocodingException('Places autocomplete $e');
    }
  }

  /// Autocomplete returns no coordinates — this resolves the chosen
  /// prediction and closes the billing session.
  @override
  Future<GeoResult?> details(String placeId) async {
    try {
      final response = await _client
          .get(
            Uri.https(
              'places.googleapis.com',
              '/v1/places/$placeId',
              {
                'languageCode': 'en',
                if (_sessionToken != null) 'sessionToken': _sessionToken!,
              },
            ),
            headers: _headers(
              'id,displayName,formattedAddress,location,addressComponents',
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw GeocodingException(
          'Place details HTTP ${response.statusCode}: '
          '${_truncateBody(response.body)}',
        );
      }
      await _onRealFetch();
      return parseGooglePlaceDetails(response.body);
    } on GeocodingException {
      rethrow;
    } catch (e) {
      throw GeocodingException('Place details $e');
    } finally {
      _sessionToken = null; // session ends with Details
    }
  }

  @override
  Future<GeoResult?> reverse(double lat, double lon) async {
    try {
      final response = await _client
          .get(
            Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
              'latlng': '$lat,$lon',
              'language': 'en',
              'key': _apiKey,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw GeocodingException(
          'Reverse geocode HTTP ${response.statusCode}: '
          '${_truncateBody(response.body)}',
        );
      }
      await _onRealFetch();
      return parseGoogleReverse(response.body);
    } on GeocodingException {
      rethrow;
    } catch (e) {
      throw GeocodingException('Reverse geocode $e');
    }
  }
}

/// Keeps debug-console noise down when an API error body is a wall of JSON.
String _truncateBody(String body, [int max = 300]) =>
    body.length <= max ? body : '${body.substring(0, max)}…';

/// Reads a nested string field out of decoded JSON one typed step at a
/// time — `map['a']['b']` trips `avoid_dynamic_calls` because the first
/// index returns `dynamic` and indexing *that* is an unverifiable dynamic
/// call, even though `map['a']?.toString()` alone is fine (Object members
/// are exempt from the lint, indexing isn't).
String? _nestedString(Object? node, List<String> path) {
  var current = node;
  for (final key in path) {
    if (current is! Map<String, dynamic>) return null;
    current = current[key];
  }
  return current?.toString();
}

/// Pure parsers — unit-tested against fixture JSON, no network.
List<GeoResult> parseGooglePredictions(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) return const [];
  final suggestions = decoded['suggestions'];
  if (suggestions is! List) return const [];
  final results = <GeoResult>[];
  for (final s in suggestions) {
    if (s is! Map<String, dynamic>) continue;
    final prediction = s['placePrediction'];
    if (prediction is! Map<String, dynamic>) continue;
    final placeId = prediction['placeId']?.toString();
    if (placeId == null || placeId.isEmpty) continue;
    final structured = prediction['structuredFormat'];
    final mainText = _nestedString(structured, ['mainText', 'text']);
    final secondary = _nestedString(structured, ['secondaryText', 'text']);
    final full = _nestedString(prediction, ['text', 'text']);
    results.add(
      GeoResult(
        name: mainText ?? full ?? '',
        displayName: secondary ?? full ?? '',
        // Coordinates arrive with Place Details.
        lat: 0,
        lon: 0,
        placeId: placeId,
      ),
    );
  }
  return results;
}

GeoResult? parseGooglePlaceDetails(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) return null;
  final location = decoded['location'];
  if (location is! Map) return null;
  final lat = (location['latitude'] as num?)?.toDouble();
  final lon = (location['longitude'] as num?)?.toDouble();
  if (lat == null || lon == null) return null;

  final displayName = decoded['displayName'];
  final name = displayName is Map ? displayName['text']?.toString() ?? '' : '';
  final address = decoded['formattedAddress']?.toString() ?? '';
  final (country, city) = _componentsOf(decoded['addressComponents']);

  return GeoResult(
    name: name.isEmpty ? address.split(',').first.trim() : name,
    displayName: address,
    lat: lat,
    lon: lon,
    country: country,
    city: city,
    placeId: decoded['id']?.toString(),
  );
}

GeoResult? parseGoogleReverse(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) return null;
  final results = decoded['results'];
  if (results is! List || results.isEmpty) return null;
  final first = results.first;
  if (first is! Map) return null;
  final geometry = first['geometry'];
  final location = geometry is Map ? geometry['location'] : null;
  if (location is! Map) return null;
  final lat = (location['lat'] as num?)?.toDouble();
  final lon = (location['lng'] as num?)?.toDouble();
  if (lat == null || lon == null) return null;

  final address = first['formatted_address']?.toString() ?? '';
  final (country, city) = _legacyComponentsOf(first['address_components']);
  return GeoResult(
    name: address.split(',').first.trim(),
    displayName: address,
    lat: lat,
    lon: lon,
    country: country,
    city: city,
  );
}

(String, String) _componentsOf(Object? components) {
  var country = '';
  var city = '';
  if (components is List) {
    for (final c in components) {
      if (c is! Map) continue;
      final types = (c['types'] as List?)?.map((t) => t.toString()) ?? const [];
      final value = c['longText']?.toString() ?? '';
      if (types.contains('country')) country = value;
      if (city.isEmpty &&
          (types.contains('locality') ||
              types.contains('postal_town') ||
              types.contains('administrative_area_level_2'))) {
        city = value;
      }
    }
  }
  return (country, city);
}

(String, String) _legacyComponentsOf(Object? components) {
  var country = '';
  var city = '';
  if (components is List) {
    for (final c in components) {
      if (c is! Map) continue;
      final types = (c['types'] as List?)?.map((t) => t.toString()) ?? const [];
      final value = c['long_name']?.toString() ?? '';
      if (types.contains('country')) country = value;
      if (city.isEmpty &&
          (types.contains('locality') ||
              types.contains('postal_town') ||
              types.contains('administrative_area_level_2'))) {
        city = value;
      }
    }
  }
  return (country, city);
}
