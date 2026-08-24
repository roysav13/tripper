import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/settings/settings_service.dart'
    show placesApiCallCountProvider;
import 'google_places_geocoder.dart';

/// One geocoding hit: coordinates plus the fields the place form can prefill.
@immutable
class GeoResult {
  const GeoResult({
    required this.name,
    required this.displayName,
    required this.lat,
    required this.lon,
    this.country = '',
    this.city = '',
    this.placeId,
  });

  final String name;
  final String displayName;
  final double lat;
  final double lon;
  final String country;
  final String city;

  /// Set by Google autocomplete; such results carry no coordinates until
  /// [Geocoder.details] resolves them.
  final String? placeId;

  bool get needsDetails => placeId != null && lat == 0 && lon == 0;
}

/// [reason] is diagnostic-only (printed to the debug console, never shown
/// to the user — the UI always shows the ARB `mapSearchOffline` string). It
/// carries the real HTTP status/body or exception so a search failure can
/// be told apart from an actual dead network when debugging.
class GeocodingException implements Exception {
  const GeocodingException([this.reason = 'unknown']);

  final String reason;

  @override
  String toString() => 'GeocodingException: $reason';
}

/// Pure parser for Nominatim jsonv2 — unit-tested against fixture JSON.
List<GeoResult> parseNominatim(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! List) return const [];
  final results = <GeoResult>[];
  for (final item in decoded) {
    if (item is! Map) continue;
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');
    if (lat == null || lon == null) continue;
    final displayName = item['display_name']?.toString() ?? '';
    final address = item['address'];
    var country = '';
    var city = '';
    if (address is Map) {
      country = address['country']?.toString() ?? '';
      city = (address['city'] ?? address['town'] ?? address['village'])
              ?.toString() ??
          '';
    }
    final name = item['name']?.toString().trim();
    results.add(
      GeoResult(
        name: (name == null || name.isEmpty)
            ? displayName.split(',').first.trim()
            : name,
        displayName: displayName,
        lat: lat,
        lon: lon,
        country: country,
        city: city,
      ),
    );
  }
  return results;
}

/// Pure parser for a single Nominatim reverse-lookup response.
GeoResult? parseNominatimReverse(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) return null;
  final lat = double.tryParse(decoded['lat']?.toString() ?? '');
  final lon = double.tryParse(decoded['lon']?.toString() ?? '');
  if (lat == null || lon == null) return null;
  final displayName = decoded['display_name']?.toString() ?? '';
  final address = decoded['address'];
  var country = '';
  var city = '';
  if (address is Map) {
    country = address['country']?.toString() ?? '';
    city = (address['city'] ??
                address['town'] ??
                address['village'] ??
                address['municipality'] ??
                address['county'])
            ?.toString() ??
        '';
  }
  final name = decoded['name']?.toString().trim();
  return GeoResult(
    name: (name == null || name.isEmpty)
        ? displayName.split(',').first.trim()
        : name,
    displayName: displayName,
    lat: lat,
    lon: lon,
    country: country,
    city: city,
  );
}

/// Widget tests fake at this boundary.
abstract interface class Geocoder {
  Future<List<GeoResult>> search(String query);

  /// Coordinates -> address details (fills city/country for shared pins).
  Future<GeoResult?> reverse(double lat, double lon);

  /// Resolves a [GeoResult.placeId] to coordinates. Providers that already
  /// return coordinates from search (Nominatim) return null.
  Future<GeoResult?> details(String placeId);
}

/// OSM Nominatim — free, keyless fallback when no Google key is configured.
/// English labels via accept-language. Usage policy: identifying User-Agent,
/// no bulk queries. Network-only: callers degrade gracefully offline.
class NominatimGeocoder implements Geocoder {
  NominatimGeocoder(this._client);

  final http.Client _client;

  @override
  Future<List<GeoResult>> search(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '6',
      'addressdetails': '1',
      'accept-language': 'en',
    });
    try {
      final response = await _client.get(
        uri,
        headers: {'User-Agent': 'tripper/0.1 (dev.roysav.tripper)'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw GeocodingException(
          'Nominatim search HTTP ${response.statusCode}: '
          '${_truncate(response.body)}',
        );
      }
      return parseNominatim(response.body);
    } on GeocodingException {
      rethrow;
    } catch (e) {
      throw GeocodingException('Nominatim search $e');
    }
  }

  /// Nominatim search already returns coordinates — nothing to resolve.
  @override
  Future<GeoResult?> details(String placeId) async => null;

  @override
  Future<GeoResult?> reverse(double lat, double lon) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': '$lat',
      'lon': '$lon',
      'format': 'jsonv2',
      'addressdetails': '1',
      'accept-language': 'en',
    });
    try {
      final response = await _client.get(
        uri,
        headers: {'User-Agent': 'tripper/0.1 (dev.roysav.tripper)'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw GeocodingException(
          'Nominatim reverse HTTP ${response.statusCode}: '
          '${_truncate(response.body)}',
        );
      }
      return parseNominatimReverse(response.body);
    } on GeocodingException {
      rethrow;
    } catch (e) {
      throw GeocodingException('Nominatim reverse $e');
    }
  }
}

/// Keeps debug-console noise down when an API error body is a wall of JSON.
String _truncate(String body, [int max = 300]) =>
    body.length <= max ? body : '${body.substring(0, max)}…';

/// What a shared Google Maps link becomes after enrichment.
@immutable
class SharedPlacePrefill {
  const SharedPlacePrefill({
    this.name,
    this.lat,
    this.lng,
    this.country = '',
    this.city = '',
  });

  final String? name;
  final double? lat;
  final double? lng;
  final String country;
  final String city;
}

/// Fills in whatever the link itself didn't carry (SPEC §3.1):
/// coordinates -> reverse geocode for city/country; name only -> forward
/// search for coordinates. Any network failure degrades to what we had.
Future<SharedPlacePrefill> enrichSharedPlace({
  required Geocoder geocoder,
  String? name,
  double? lat,
  double? lng,
}) async {
  if (lat != null && lng != null) {
    try {
      final hit = await geocoder.reverse(lat, lng);
      return SharedPlacePrefill(
        // A name from the link is more specific than the reverse hit.
        name: (name != null && name.isNotEmpty) ? name : hit?.name,
        lat: lat,
        lng: lng,
        country: hit?.country ?? '',
        city: hit?.city ?? '',
      );
    } catch (_) {
      return SharedPlacePrefill(name: name, lat: lat, lng: lng);
    }
  }
  if (name != null && name.trim().isNotEmpty) {
    try {
      final results = await geocoder.search(name);
      if (results.isNotEmpty) {
        var hit = results.first;
        // Google predictions need a second call for coordinates.
        if (hit.needsDetails) {
          hit = await geocoder.details(hit.placeId!) ?? hit;
        }
        if (!hit.needsDetails) {
          return SharedPlacePrefill(
            name: name,
            lat: hit.lat,
            lng: hit.lon,
            country: hit.country,
            city: hit.city,
          );
        }
      }
    } catch (_) {
      // Offline — keep the name, user can locate later.
    }
  }
  return SharedPlacePrefill(name: name, lat: lat, lng: lng);
}

/// Google Places when a key is configured; Nominatim otherwise, so the app
/// still works for anyone building without a key.
final geocoderProvider = Provider<Geocoder>((ref) {
  final client = http.Client();
  if (kGoogleMapsApiKey.isEmpty) return NominatimGeocoder(client);
  return GooglePlacesGeocoder(
    client,
    apiKey: kGoogleMapsApiKey,
    onRealFetch: () =>
        ref.read(placesApiCallCountProvider.notifier).increment(),
  );
});
