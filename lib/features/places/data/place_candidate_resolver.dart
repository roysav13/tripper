import 'package:flutter/foundation.dart';

import 'geocoding_service.dart';
import 'place_summary_service.dart';

/// A place candidate resolved from a name — the output of Wikipedia-then-
/// Places resolution (design spec §5.6). Shown on the review screen before
/// the user decides whether to add it.
@immutable
class ResolvedPlaceCandidate {
  const ResolvedPlaceCandidate({
    required this.name,
    this.summary,
    this.lat,
    this.lng,
    this.country = '',
    this.city = '',
  });

  final String name;
  final String? summary;
  final double? lat;
  final double? lng;
  final String country;
  final String city;

  bool get hasLocation => lat != null && lng != null;
}

/// Wikipedia first; Google Places fills only whatever Wikipedia didn't
/// supply (design spec §4 step 2 / §5.6):
/// - Wikipedia had coordinates → reverse-geocode them for city/country only
/// - Wikipedia had no coordinates → forward-search Places by name
/// - Wikipedia found nothing → Places is the sole source
/// Every branch degrades to whatever was already resolved on failure —
/// never throws, never blocks (CLAUDE.md hard rule 4).
Future<ResolvedPlaceCandidate> resolvePlaceCandidate({
  required PlaceLocationSummaryFetcher wikipedia,
  required Geocoder geocoder,
  required String name,
}) async {
  WikipediaLookup? wiki;
  try {
    wiki = await wikipedia.lookup(name: name);
  } catch (_) {
    // Wikipedia is optional; degrade gracefully
  }

  if (wiki != null && wiki.hasCoordinates) {
    try {
      final hit = await geocoder.reverse(wiki.lat!, wiki.lng!);
      return ResolvedPlaceCandidate(
        name: name,
        summary: wiki.summary,
        lat: wiki.lat,
        lng: wiki.lng,
        country: hit?.country ?? '',
        city: hit?.city ?? '',
      );
    } catch (_) {
      return ResolvedPlaceCandidate(
        name: name,
        summary: wiki.summary,
        lat: wiki.lat,
        lng: wiki.lng,
      );
    }
  }

  try {
    final results = await geocoder.search(name);
    if (results.isEmpty) {
      return ResolvedPlaceCandidate(name: name, summary: wiki?.summary);
    }
    var hit = results.first;
    if (hit.needsDetails) {
      hit = await geocoder.details(hit.placeId!) ?? hit;
    }
    if (hit.needsDetails) {
      return ResolvedPlaceCandidate(name: name, summary: wiki?.summary);
    }
    return ResolvedPlaceCandidate(
      name: name,
      summary: wiki?.summary,
      lat: hit.lat,
      lng: hit.lon,
      country: hit.country,
      city: hit.city,
    );
  } catch (_) {
    return ResolvedPlaceCandidate(name: name, summary: wiki?.summary);
  }
}
