import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'packing_tables.dart';

part 'packing_dao.g.dart';

@DriftAccessor(
  tables: [PackingTemplates, PackingTemplateItems, TripPackingItems],
)
class PackingDao extends DatabaseAccessor<AppDatabase> with _$PackingDaoMixin {
  PackingDao(super.db);

  Stream<List<PackingTemplateRow>> watchTemplates() {
    return (select(packingTemplates)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<PackingTemplateRow?> getTemplateById(String id) =>
      (select(packingTemplates)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> insertTemplate(PackingTemplateRow row) =>
      into(packingTemplates).insert(row);

  Future<void> updateTemplate(PackingTemplateRow row) =>
      update(packingTemplates).replace(row);

  Future<void> deleteTemplate(String id) =>
      (delete(packingTemplates)..where((t) => t.id.equals(id))).go();

  Stream<List<PackingTemplateItemRow>> watchTemplateItems(String templateId) {
    return (select(packingTemplateItems)
          ..where((i) => i.templateId.equals(templateId))
          ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
        .watch();
  }

  Future<List<PackingTemplateItemRow>> getTemplateItems(String templateId) =>
      (select(packingTemplateItems)
            ..where((i) => i.templateId.equals(templateId)))
          .get();

  Future<PackingTemplateItemRow?> getTemplateItemById(String id) =>
      (select(packingTemplateItems)..where((i) => i.id.equals(id)))
          .getSingleOrNull();

  Future<void> insertTemplateItem(PackingTemplateItemRow row) =>
      into(packingTemplateItems).insert(row);

  Future<void> updateTemplateItem(PackingTemplateItemRow row) =>
      update(packingTemplateItems).replace(row);

  Future<void> deleteTemplateItem(String id) =>
      (delete(packingTemplateItems)..where((i) => i.id.equals(id))).go();

  Stream<List<TripPackingItemRow>> watchTripItems(String tripId) {
    return (select(tripPackingItems)
          ..where((i) => i.tripId.equals(tripId))
          ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
        .watch();
  }

  Future<List<TripPackingItemRow>> getTripItems(String tripId) =>
      (select(tripPackingItems)..where((i) => i.tripId.equals(tripId))).get();

  Future<TripPackingItemRow?> getTripItemById(String id) =>
      (select(tripPackingItems)..where((i) => i.id.equals(id)))
          .getSingleOrNull();

  Future<void> insertTripItem(TripPackingItemRow row) =>
      into(tripPackingItems).insert(row);

  /// All-or-nothing insert — applying a template must not be able to leave a
  /// half-copied list behind if one row fails partway through.
  Future<void> insertTripItems(List<TripPackingItemRow> rows) {
    return transaction(() async {
      for (final row in rows) {
        await into(tripPackingItems).insert(row);
      }
    });
  }

  Future<void> updateTripItem(TripPackingItemRow row) =>
      update(tripPackingItems).replace(row);

  Future<void> deleteTripItem(String id) =>
      (delete(tripPackingItems)..where((i) => i.id.equals(id))).go();
}
