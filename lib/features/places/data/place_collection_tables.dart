import 'package:drift/drift.dart';

import 'place_tables.dart';

/// A user-made grouping of places ("Tokyo day trips", "Food") — orthogonal
/// to [Places.category] (what a place *is*) and independent of any trip. A
/// place can belong to any number of collections at once; see
/// [PlaceCollectionMemberships].
@DataClassName('PlaceCollectionRow')
class PlaceCollections extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Many-to-many join: a place can sit in several collections, a collection
/// holds several places. Both FKs cascade — deleting either side of the
/// relationship removes just the membership row, never the place or the
/// collection's other memberships.
@DataClassName('PlaceCollectionMembershipRow')
class PlaceCollectionMemberships extends Table {
  TextColumn get collectionId =>
      text().references(PlaceCollections, #id, onDelete: KeyAction.cascade)();
  TextColumn get placeId =>
      text().references(Places, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {collectionId, placeId};
}
