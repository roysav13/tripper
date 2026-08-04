import 'package:flutter/foundation.dart';

import 'journal_photo.dart';

@immutable
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.tripId,
    required this.summary,
    required this.loggedAt,
    required this.createdAt,
    this.lat,
    this.lng,
    this.placeName,
    this.placeId,
    this.photos = const [],
  });

  final String id;
  final String tripId;
  final String summary;

  /// User-editable log time — distinct from [createdAt].
  final DateTime loggedAt;

  /// Immutable audit stamp — never shown or edited.
  final DateTime createdAt;

  final double? lat;
  final double? lng;
  final String? placeName;

  /// The Place this entry corresponds to, if any (Place<->JournalEntry
  /// correlation) — set when the entry's location was picked from an
  /// existing Place, or when this entry was auto-created because a Place
  /// was marked visited.
  final String? placeId;

  final List<JournalPhoto> photos;

  bool get hasLocation => lat != null && lng != null;
  bool get hasPhotos => photos.isNotEmpty;

  JournalEntry copyWith({
    String? summary,
    DateTime? loggedAt,
    double? Function()? lat,
    double? Function()? lng,
    String? Function()? placeName,
    String? Function()? placeId,
    List<JournalPhoto>? photos,
  }) {
    return JournalEntry(
      id: id,
      tripId: tripId,
      summary: summary ?? this.summary,
      loggedAt: loggedAt ?? this.loggedAt,
      createdAt: createdAt,
      lat: lat == null ? this.lat : lat(),
      lng: lng == null ? this.lng : lng(),
      placeName: placeName == null ? this.placeName : placeName(),
      placeId: placeId == null ? this.placeId : placeId(),
      photos: photos ?? this.photos,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is JournalEntry &&
      other.id == id &&
      other.tripId == tripId &&
      other.summary == summary &&
      other.loggedAt == loggedAt &&
      other.createdAt == createdAt &&
      other.lat == lat &&
      other.lng == lng &&
      other.placeName == placeName &&
      other.placeId == placeId &&
      listEquals(other.photos, photos);

  @override
  int get hashCode => Object.hash(
        id,
        tripId,
        summary,
        loggedAt,
        createdAt,
        lat,
        lng,
        placeName,
        placeId,
        Object.hashAll(photos),
      );
}
