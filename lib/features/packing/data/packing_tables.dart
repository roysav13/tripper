import 'package:drift/drift.dart';

import '../../trips/data/trip_tables.dart';

@DataClassName('PackingTemplateRow')
class PackingTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PackingTemplateItemRow')
class PackingTemplateItems extends Table {
  TextColumn get id => text()();
  TextColumn get templateId =>
      text().references(PackingTemplates, #id, onDelete: KeyAction.cascade)();

  /// Index into the PackingCategory enum (domain layer).
  IntColumn get category => integer()();
  TextColumn get label => text()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TripPackingItemRow')
class TripPackingItems extends Table {
  TextColumn get id => text()();

  /// Cascade, unlike Places (SET NULL): a packing list without its trip
  /// is meaningless — same reasoning as Expenses.tripId.
  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();

  /// Index into the PackingCategory enum (domain layer).
  IntColumn get category => integer()();
  TextColumn get label => text()();

  /// Index into the PackingItemStatus enum (domain layer). Non-clothing
  /// items only ever hold toPack(0)/packed(1); clothing items use all 5.
  IntColumn get status => integer()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
