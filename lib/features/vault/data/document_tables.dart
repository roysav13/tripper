import 'package:drift/drift.dart';

import '../../trips/data/trip_tables.dart';

@DataClassName('DocumentRow')
class Documents extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 120)();

  /// Index into DocumentCategory enum.
  IntColumn get category => integer()();

  /// Null for manual records (no file attached).
  TextColumn get filePath => text().nullable()();
  TextColumn get mimeType => text().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();

  /// Global documents (passport, insurance) outlive trips.
  BoolColumn get isGlobal => boolean().withDefault(const Constant(false))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  /// Category-specific fields (flight number, confirmation code…) as JSON.
  TextColumn get detailsJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TripDocumentRow')
class TripDocuments extends Table {
  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get documentId =>
      text().references(Documents, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {tripId, documentId};
}
