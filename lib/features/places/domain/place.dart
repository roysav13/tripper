import 'package:flutter/foundation.dart';

/// Wishlist carries the color; visited recedes to gray (design decision).
enum PlaceStatus { wantToGo, beenThere }

/// Order is stable — stored as index in the DB. Append only.
enum PlaceCategory {
  hotel,
  restaurant,
  coffeeShop,
  bar,
  attraction,
  museum,
  amusementPark,
  trek,
  beach,
  shopping,
  nature,
  other,
}

@immutable
class Place {
  const Place({
    required this.id,
    required this.name,
    this.lat,
    this.lng,
    this.country = '',
    this.city = '',
    this.status = PlaceStatus.wantToGo,
    this.visitedAt,
    this.tripId,
    this.notes = '',
    this.category,
    this.summary,
    this.summaryFetchedAt,
    this.plannedDate,
  });

  final String id;
  final String name;
  final double? lat;
  final double? lng;
  final String country;
  final String city;
  final PlaceStatus status;
  final DateTime? visitedAt;
  final String? tripId;
  final String notes;

  /// Null = uncategorized — every place that existed before this field
  /// shipped has no category, and that's a real, distinct state from
  /// "Other" (defaulting old rows to "Other" would invent a fact nobody
  /// entered).
  final PlaceCategory? category;

  /// Wikipedia-sourced summary of the place, fetched automatically once
  /// on save. Null with [summaryFetchedAt] also null = never attempted
  /// yet (fetch is in flight or the place predates this feature). Null
  /// with [summaryFetchedAt] set = attempted and nothing came back
  /// (offline, or no matching Wikipedia article) — a real, distinct state
  /// from "not tried", so the UI never retries a place that already came
  /// back empty.
  final String? summary;
  final DateTime? summaryFetchedAt;

  /// Which day of the trip this place is intended for — a deliberately
  /// minimal successor to the withdrawn Plan tab
  /// (docs/adr/ADR-001-itinerary-redesign.md): no time, no ordering, no
  /// derived anchors. Only ever set via the Near By add flow in this
  /// round; editing it from the general place editor is a later, separate
  /// decision.
  final DateTime? plannedDate;

  bool get hasSummary => summary != null && summary!.trim().isNotEmpty;

  bool get isVisited => status == PlaceStatus.beenThere;
  bool get hasLocation => lat != null && lng != null;

  Place copyWith({
    String? name,
    double? Function()? lat,
    double? Function()? lng,
    String? country,
    String? city,
    PlaceStatus? status,
    DateTime? Function()? visitedAt,
    String? Function()? tripId,
    String? notes,
    PlaceCategory? Function()? category,
    String? Function()? summary,
    DateTime? Function()? summaryFetchedAt,
    DateTime? Function()? plannedDate,
  }) {
    return Place(
      id: id,
      name: name ?? this.name,
      lat: lat == null ? this.lat : lat(),
      lng: lng == null ? this.lng : lng(),
      country: country ?? this.country,
      city: city ?? this.city,
      status: status ?? this.status,
      visitedAt: visitedAt == null ? this.visitedAt : visitedAt(),
      tripId: tripId == null ? this.tripId : tripId(),
      notes: notes ?? this.notes,
      category: category == null ? this.category : category(),
      summary: summary == null ? this.summary : summary(),
      summaryFetchedAt:
          summaryFetchedAt == null ? this.summaryFetchedAt : summaryFetchedAt(),
      plannedDate: plannedDate == null ? this.plannedDate : plannedDate(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.id == id &&
      other.name == name &&
      other.lat == lat &&
      other.lng == lng &&
      other.country == country &&
      other.city == city &&
      other.status == status &&
      other.visitedAt == visitedAt &&
      other.tripId == tripId &&
      other.notes == notes &&
      other.category == category &&
      other.summary == summary &&
      other.summaryFetchedAt == summaryFetchedAt &&
      other.plannedDate == plannedDate;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        lat,
        lng,
        country,
        city,
        status,
        visitedAt,
        tripId,
        notes,
        category,
        summary,
        summaryFetchedAt,
        plannedDate,
      );
}

/// Trophy-case stats over existing data — no new entities (SPEC §3.1).
({int countries, int visited}) visitedStats(List<Place> places) {
  final visited = places.where((p) => p.isVisited).toList();
  final countries = {
    for (final p in visited)
      if (p.country.trim().isNotEmpty) p.country.trim().toLowerCase(),
  };
  return (countries: countries.length, visited: visited.length);
}
