import 'package:flutter/foundation.dart';

/// Wishlist carries the color; visited recedes to gray (design decision).
enum PlaceStatus { wantToGo, beenThere }

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
      other.notes == notes;

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
      );
}

/// Section ordering (SPEC): wishlist first (by name), visited last
/// (most recently visited first).
List<Place> sortForList(List<Place> places) {
  final want = places.where((p) => !p.isVisited).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  final been = places.where((p) => p.isVisited).toList()
    ..sort((a, b) {
      final av = a.visitedAt, bv = b.visitedAt;
      if (av == null && bv == null) return 0;
      if (av == null) return 1;
      if (bv == null) return -1;
      return bv.compareTo(av);
    });
  return [...want, ...been];
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
