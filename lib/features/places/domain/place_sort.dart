import 'dart:math' as math;

import 'place.dart';

/// Append-only — stored nowhere on disk, but new fields should still only
/// ever be appended (matches the append-only discipline used for the
/// persisted enums in this feature).
enum PlaceSortField { recommended, name, visitedDate, distance }

/// Reproduces the original section ordering (wishlist first by name,
/// visited last by most-recently-visited): a single comparator that
/// partitions on [Place.isVisited] first, so a plain `.sort()` with this
/// comparator alone yields the same two-section layout `sortForList` used
/// to build by concatenating two separately-sorted lists.
int comparePlacesRecommended(Place a, Place b) {
  if (a.isVisited != b.isVisited) return a.isVisited ? 1 : -1;
  if (!a.isVisited) {
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
  final av = a.visitedAt, bv = b.visitedAt;
  if (av == null && bv == null) return 0;
  if (av == null) return 1;
  if (bv == null) return -1;
  return bv.compareTo(av);
}

int comparePlacesByName(Place a, Place b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

/// Only ever called on places with a non-null [Place.visitedAt] — the
/// sort engine partitions valueless items out via `hasValue` before this
/// runs.
int comparePlacesByVisitedDate(Place a, Place b) =>
    a.visitedAt!.compareTo(b.visitedAt!);

// Earth's mean radius in km.
const _earthRadiusKm = 6371.0;

double _degToRad(double deg) => deg * math.pi / 180;

/// Great-circle (haversine) distance between two lat/lng points, in km.
double _haversineDistanceKm(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return _earthRadiusKm * c;
}

/// Only ever called on places with a location (the sort engine partitions
/// valueless items — no [Place.lat]/[Place.lng], or no [lat]/[lng] fix
/// yet — out via `hasValue` before this runs). [lat]/[lng] is the
/// device's current fix, supplied fresh by the caller on every sort
/// rather than read from global state (no `DateTime.now()`-style hidden
/// input — CLAUDE.md hard rule 2 applies just as much to "current
/// position" as it does to "now").
int comparePlacesByDistance(
  Place a,
  Place b, {
  required double lat,
  required double lng,
}) {
  final da = _haversineDistanceKm(lat, lng, a.lat!, a.lng!);
  final db = _haversineDistanceKm(lat, lng, b.lat!, b.lng!);
  return da.compareTo(db);
}

/// Distance from the device fix at [lat]/[lng] to [place], in km. Only
/// ever called on a place with [Place.hasLocation] true.
double placeDistanceFromKm(
  Place place, {
  required double lat,
  required double lng,
}) =>
    _haversineDistanceKm(lat, lng, place.lat!, place.lng!);

/// Distance between two raw coordinate pairs, in km — same haversine math
/// as [placeDistanceFromKm], for callers (like [NearbyPlaceResult]) that
/// aren't a [Place].
double distanceBetweenKm({
  required double lat1,
  required double lng1,
  required double lat2,
  required double lng2,
}) =>
    _haversineDistanceKm(lat1, lng1, lat2, lng2);
