import 'dart:math' as math;

import 'journal_entry.dart';

/// The chronologically-latest located entry, or null if none are located.
/// Used by the globe to decide what to focus on when it opens or when a
/// new entry is logged.
JournalEntry? latestLocatedEntry(List<JournalEntry> entries) {
  JournalEntry? latest;
  for (final entry in entries) {
    if (!entry.hasLocation) continue;
    if (latest == null || entry.loggedAt.isAfter(latest.loggedAt)) {
      latest = entry;
    }
  }
  return latest;
}

/// Consecutive pairs of located entries in chronological order — the
/// journey line's segments on the globe.
List<(JournalEntry, JournalEntry)> journeyConnections(
  List<JournalEntry> entries,
) {
  final located = entries.where((e) => e.hasLocation).toList()
    ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
  return [
    for (var i = 0; i < located.length - 1; i++) (located[i], located[i + 1]),
  ];
}

/// [entries] grouped by the local calendar day of [JournalEntry.loggedAt],
/// oldest day first; entries within a day keep their relative order from
/// [entries] (the caller is expected to already pass entries in
/// chronological order — [JournalRepository.watchForTrip] does). Used by
/// the gallery timeline to decide which entries share one day-slot.
List<List<JournalEntry>> groupEntriesByDay(List<JournalEntry> entries) {
  final byDay = <DateTime, List<JournalEntry>>{};
  final order = <DateTime>[];
  for (final entry in entries) {
    final day = DateTime(
      entry.loggedAt.year,
      entry.loggedAt.month,
      entry.loggedAt.day,
    );
    if (!byDay.containsKey(day)) {
      order.add(day);
      byDay[day] = [];
    }
    byDay[day]!.add(entry);
  }
  order.sort();
  return [for (final day in order) byDay[day]!];
}

// Earth's mean radius in km — used to convert the haversine formula's
// angular distance into a real-world distance for the clustering
// threshold below.
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

/// Groups [entries] into clusters by geographic closeness, for the
/// globe's marker rendering — entries logged close together (e.g.
/// several stops in the same city) collapse into one marker instead of
/// rendering as visually-overlapping, hard-to-tap individual dots.
///
/// Unlocated entries never appear in any cluster (same exclusion as the
/// globe's own `if (!entry.hasLocation) continue` elsewhere). A cluster
/// of size 1 is the common case — most entries aren't close to any
/// other. Each returned cluster is sorted ascending by [JournalEntry.loggedAt]
/// so callers (the globe's cluster-tap → presentation-sheet flow) get a
/// sensible chronological swipe order, matching [groupEntriesByDay]'s
/// existing ordering guarantee.
///
/// The clustering threshold shrinks as [zoom] increases — `150 *
/// pow(2, -zoom)` km — deliberately using the same `2^zoom` scaling this
/// file's caller (`journal_globe.dart`'s `_handleZoomChanged`) already
/// uses to keep dot sizes visually consistent across zoom, so a
/// cluster's *apparent* on-screen size stays roughly constant as you
/// zoom rather than being a fixed geographic distance: entries cluster
/// because they'd visually collide at the current zoom, and split apart
/// once zooming in would give them enough screen space to be
/// individually tappable. The original `50` (km, at zoom 0) was picked
/// from a "same metro area" real-world-distance intuition, without
/// accounting for how much the globe's screen-scale compression shrinks
/// apparent distance: at the app's actual rest zoom of 1, 50km worked
/// out to under 1 pixel of screen distance — far tighter than the
/// ~9-10px a halo actually occupies on screen, so real visual collisions
/// at neighborhood/city-block scale went uncaught. `150` is a
/// deliberate, more modest first correction, chosen for on-device
/// re-verification rather than jumping straight to the fully
/// pixel-derived value (~500-550km) that would more precisely match
/// halo size — still a starting value for further tuning, not a final
/// answer.
///
/// Grouping is transitive: if A is within threshold of B, and B is
/// within threshold of C, all three land in one cluster even if A and C
/// alone exceed the threshold — matches how visual overlap actually
/// chains (A's halo overlapping B's overlapping C's reads as one blob).
/// O(n²) worst case; fine at the scale a single trip's entries actually
/// reach (realistically low tens).
List<List<JournalEntry>> groupEntriesByProximity(
  List<JournalEntry> entries,
  double zoom,
) {
  final located = entries.where((e) => e.hasLocation).toList();
  final thresholdKm = (150.0 * math.pow(2, -zoom)).toDouble();
  final clusters = <List<JournalEntry>>[];
  final assigned = <String>{};
  for (final seed in located) {
    if (assigned.contains(seed.id)) continue;
    final cluster = <JournalEntry>[seed];
    assigned.add(seed.id);
    var frontier = <JournalEntry>[seed];
    while (frontier.isNotEmpty) {
      final next = <JournalEntry>[];
      for (final member in frontier) {
        for (final candidate in located) {
          if (assigned.contains(candidate.id)) continue;
          final distance = _haversineDistanceKm(
            member.lat!,
            member.lng!,
            candidate.lat!,
            candidate.lng!,
          );
          if (distance <= thresholdKm) {
            cluster.add(candidate);
            assigned.add(candidate.id);
            next.add(candidate);
          }
        }
      }
      frontier = next;
    }
    cluster.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    clusters.add(cluster);
  }
  return clusters;
}
