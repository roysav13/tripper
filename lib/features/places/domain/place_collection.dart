import 'package:flutter/foundation.dart';

/// A user-made grouping of places — "Tokyo day trips", "Food". Independent
/// of [PlaceCategory] (what a place *is*) and of any trip; a place can
/// belong to any number of collections at once.
@immutable
class PlaceCollection {
  const PlaceCollection({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  PlaceCollection copyWith({String? name}) => PlaceCollection(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      other is PlaceCollection &&
      other.id == id &&
      other.name == name &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, createdAt);
}
