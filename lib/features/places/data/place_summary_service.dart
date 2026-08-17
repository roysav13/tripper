import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'place_repository.dart';

/// Widget/unit tests fake at this boundary.
abstract interface class PlaceSummaryFetcher {
  /// Best-effort — never throws. A failed lookup, no match, or no summary
  /// data for the place all resolve to `null`.
  Future<String?> fetchSummary({
    required String name,
    String city = '',
    String country = '',
    double? lat,
    double? lng,
  });
}

/// Always yields nothing — the default in tests (network stays off by
/// default, CLAUDE.md hard rule 5) so a `placeSummaryFetcherProvider`
/// left un-overridden never reaches out to the real Wikipedia API.
class NoopPlaceSummaryFetcher implements PlaceSummaryFetcher {
  const NoopPlaceSummaryFetcher();

  @override
  Future<String?> fetchSummary({
    required String name,
    String city = '',
    String country = '',
    double? lat,
    double? lng,
  }) async =>
      null;
}

const _userAgent = 'tripper/0.1 (dev.roysav.tripper)';

/// Wikipedia (English) — free, keyless, no billing tier to misconfigure,
/// and broad real-world coverage of exactly the place types this feature
/// targets (cities, parks, treks, museums, landmarks).
///
/// Two-step resolution for accuracy:
///  1. Find the right article. When coordinates are known, `geosearch`
///     (nearby-articles-by-distance) finds candidates near the pin, but
///     "nearest" alone is unreliable — the closest article to a beach's
///     pin might be an unrelated resort. So a geosearch hit is only used
///     if its title actually shares a significant word with the place
///     name ([pickBestGeoMatch]); otherwise this falls back to a plain
///     text search on name + city + country, which is what runs directly
///     when there are no coordinates at all (a place added without a
///     location).
///  2. Fetch that article's summary via the REST `page/summary` endpoint
///     — the same endpoint Wikipedia's own link-preview feature uses,
///     already a short plain-text `extract`. Disambiguation pages ("Paris
///     may refer to...") are rejected rather than shown as if they were a
///     real summary.
class WikipediaPlaceSummaryFetcher implements PlaceSummaryFetcher {
  WikipediaPlaceSummaryFetcher(this._client);

  final http.Client _client;

  /// Meters — the API's own maximum for `gsradius`.
  static const _geoRadiusMeters = 10000;
  static const _geoCandidateLimit = 10;

  @override
  Future<String?> fetchSummary({
    required String name,
    String city = '',
    String country = '',
    double? lat,
    double? lng,
  }) async {
    if (name.trim().isEmpty) return null;
    try {
      final title = await _resolveTitle(
        name: name,
        city: city,
        country: country,
        lat: lat,
        lng: lng,
      );
      if (title == null) return null;
      return await _fetchSummaryForTitle(title);
    } catch (e) {
      // Best-effort enhancement (CLAUDE.md hard rule 4) — any failure
      // (offline, timeout, malformed response) degrades to no summary,
      // never surfaces as an error to the caller.
      debugPrint('[places] wikipedia summary failed: $e');
      return null;
    }
  }

  Future<String?> _resolveTitle({
    required String name,
    required String city,
    required String country,
    double? lat,
    double? lng,
  }) async {
    if (lat != null && lng != null) {
      final candidates = await _geosearch(lat, lng);
      final geoMatch = pickBestGeoMatch(candidates, name);
      if (geoMatch != null) return geoMatch;
    }
    return _textSearch(name: name, city: city, country: country);
  }

  Future<List<String>> _geosearch(double lat, double lng) async {
    final response = await _client.get(
      Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'list': 'geosearch',
        'format': 'json',
        'gscoord': '$lat|$lng',
        'gsradius': '$_geoRadiusMeters',
        'gslimit': '$_geoCandidateLimit',
      }),
      headers: {'User-Agent': _userAgent},
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return const [];
    return parseGeosearchTitles(response.body);
  }

  Future<String?> _textSearch({
    required String name,
    required String city,
    required String country,
  }) async {
    final query = [name, city, country]
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(' ');
    if (query.isEmpty) return null;
    final response = await _client.get(
      Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'list': 'search',
        'format': 'json',
        'srsearch': query,
        'srlimit': '1',
      }),
      headers: {'User-Agent': _userAgent},
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    return parseSearchTitle(response.body);
  }

  Future<String?> _fetchSummaryForTitle(String title) async {
    final encodedTitle = Uri.encodeComponent(title.replaceAll(' ', '_'));
    final response = await _client.get(
      Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/$encodedTitle',
      ),
      headers: {'User-Agent': _userAgent},
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    return parseWikipediaSummary(response.body);
  }
}

/// Pure parser — unit-tested against fixture JSON, no network.
List<String> parseGeosearchTitles(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) return const [];
  final query = decoded['query'];
  if (query is! Map<String, dynamic>) return const [];
  final results = query['geosearch'];
  if (results is! List) return const [];
  return [
    for (final r in results)
      if (r is Map<String, dynamic> && r['title'] is String)
        r['title'] as String,
  ];
}

/// Pure parser — unit-tested against fixture JSON, no network.
String? parseSearchTitle(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) return null;
  final query = decoded['query'];
  if (query is! Map<String, dynamic>) return null;
  final results = query['search'];
  if (results is! List || results.isEmpty) return null;
  final first = results.first;
  if (first is! Map<String, dynamic>) return null;
  final title = first['title'];
  return (title is String && title.isNotEmpty) ? title : null;
}

/// Pure parser — unit-tested against fixture JSON, no network. Rejects
/// disambiguation pages ("Paris may refer to...") — that text isn't a
/// summary of anything, it's a list of other articles.
String? parseWikipediaSummary(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) return null;
  if (decoded['type'] == 'disambiguation') return null;
  final extract = decoded['extract']?.toString().trim();
  return (extract == null || extract.isEmpty) ? null : extract;
}

/// Proximity alone is weak evidence — the nearest Wikipedia article to a
/// pin is often an unrelated nearby landmark — so a candidate is only
/// accepted if its title shares a significant (4+ letter) word with
/// [name]. Returns null (not a guess) when nothing agrees, so the caller
/// falls back to a text search instead.
String? pickBestGeoMatch(List<String> candidateTitles, String name) {
  final nameWords = _significantWords(name);
  if (nameWords.isEmpty) return null;
  for (final title in candidateTitles) {
    if (_significantWords(title).any(nameWords.contains)) return title;
  }
  return null;
}

Set<String> _significantWords(String s) => s
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9]+'))
    .where((w) => w.length >= 4)
    .toSet();

/// Fetches and stores in one step — the fire-and-forget call site (place
/// save) doesn't need to know about either boundary separately.
Future<void> fetchAndStorePlaceSummary({
  required PlaceSummaryFetcher fetcher,
  required PlaceRepository repo,
  required String placeId,
  required String name,
  String city = '',
  String country = '',
  double? lat,
  double? lng,
}) async {
  final summary = await fetcher.fetchSummary(
    name: name,
    city: city,
    country: country,
    lat: lat,
    lng: lng,
  );
  await repo.setSummary(placeId, summary: summary);
}
