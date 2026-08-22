import '../../../core/database/app_database.dart';
import '../domain/packing_category.dart';
import '../domain/packing_item_status.dart';
import '../domain/packing_template.dart';
import '../domain/trip_packing_item.dart';
import 'packing_dao.dart';

/// Widget tests mock at this boundary (testing rules).
abstract interface class PackingRepository {
  Stream<List<PackingTemplate>> watchTemplates();
  Future<String> createTemplate({required String name});
  Future<void> renameTemplate(String id, String name);
  Future<void> deleteTemplate(String id);

  Stream<List<PackingTemplateItem>> watchTemplateItems(String templateId);
  Future<String> addTemplateItem({
    required String templateId,
    required PackingCategory category,
    required String label,
  });
  Future<void> updateTemplateItem(PackingTemplateItem item);
  Future<void> deleteTemplateItem(String id);

  Stream<List<TripPackingItem>> watchTripItems(String tripId);
  Future<String> addTripItem({
    required String tripId,
    required PackingCategory category,
    required String label,
  });
  Future<void> updateTripItemLabel(String id, String label);
  Future<void> updateTripItemStatus(String id, PackingItemStatus status);
  Future<void> deleteTripItem(String id);

  /// Copies every item from [templateId] into [tripId]'s list, each
  /// starting at [PackingItemStatus.toPack]. Appends — never replaces —
  /// and keeps no link back to the template afterward (see design spec,
  /// "Apply semantics").
  Future<void> applyTemplate({
    required String tripId,
    required String templateId,
  });
}

class DriftPackingRepository implements PackingRepository {
  DriftPackingRepository(this._dao, this._idGen);

  final PackingDao _dao;
  final String Function() _idGen;

  @override
  Stream<List<PackingTemplate>> watchTemplates() =>
      _dao.watchTemplates().map((rows) => rows.map(_templateToDomain).toList());

  @override
  Future<String> createTemplate({required String name}) async {
    final id = _idGen();
    await _dao.insertTemplate(PackingTemplateRow(id: id, name: name.trim()));
    return id;
  }

  @override
  Future<void> renameTemplate(String id, String name) async {
    final existing = await _dao.getTemplateById(id);
    if (existing == null) return;
    await _dao.updateTemplate(existing.copyWith(name: name.trim()));
  }

  @override
  Future<void> deleteTemplate(String id) => _dao.deleteTemplate(id);

  @override
  Stream<List<PackingTemplateItem>> watchTemplateItems(String templateId) =>
      _dao
          .watchTemplateItems(templateId)
          .map((rows) => rows.map(_templateItemToDomain).toList());

  @override
  Future<String> addTemplateItem({
    required String templateId,
    required PackingCategory category,
    required String label,
  }) async {
    final id = _idGen();
    final existing = await _dao.getTemplateItems(templateId);
    final sortOrder = _nextSortOrder(
      existing
          .where((i) => i.category == category.index)
          .map((i) => i.sortOrder),
    );
    await _dao.insertTemplateItem(
      PackingTemplateItemRow(
        id: id,
        templateId: templateId,
        category: category.index,
        label: label.trim(),
        sortOrder: sortOrder,
      ),
    );
    return id;
  }

  @override
  Future<void> updateTemplateItem(PackingTemplateItem item) =>
      _dao.updateTemplateItem(
        PackingTemplateItemRow(
          id: item.id,
          templateId: item.templateId,
          category: item.category.index,
          label: item.label.trim(),
          sortOrder: item.sortOrder,
        ),
      );

  @override
  Future<void> deleteTemplateItem(String id) => _dao.deleteTemplateItem(id);

  @override
  Stream<List<TripPackingItem>> watchTripItems(String tripId) => _dao
      .watchTripItems(tripId)
      .map((rows) => rows.map(_tripItemToDomain).toList());

  @override
  Future<String> addTripItem({
    required String tripId,
    required PackingCategory category,
    required String label,
  }) async {
    final id = _idGen();
    final existing = await _dao.getTripItems(tripId);
    final sortOrder = _nextSortOrder(
      existing
          .where((i) => i.category == category.index)
          .map((i) => i.sortOrder),
    );
    await _dao.insertTripItem(
      TripPackingItemRow(
        id: id,
        tripId: tripId,
        category: category.index,
        label: label.trim(),
        status: PackingItemStatus.toPack.index,
        sortOrder: sortOrder,
      ),
    );
    return id;
  }

  @override
  Future<void> updateTripItemLabel(String id, String label) async {
    final existing = await _dao.getTripItemById(id);
    if (existing == null) return;
    await _dao.updateTripItem(existing.copyWith(label: label.trim()));
  }

  @override
  Future<void> updateTripItemStatus(
    String id,
    PackingItemStatus status,
  ) async {
    final existing = await _dao.getTripItemById(id);
    if (existing == null) return;
    await _dao.updateTripItem(existing.copyWith(status: status.index));
  }

  @override
  Future<void> deleteTripItem(String id) => _dao.deleteTripItem(id);

  @override
  Future<void> applyTemplate({
    required String tripId,
    required String templateId,
  }) async {
    final templateItems = await _dao.getTemplateItems(templateId);
    final existingTripItems = await _dao.getTripItems(tripId);
    final nextSortOrder = <int, int>{
      for (final category in PackingCategory.values)
        category.index: _nextSortOrder(
          existingTripItems
              .where((i) => i.category == category.index)
              .map((i) => i.sortOrder),
        ),
    };
    final rows = <TripPackingItemRow>[];
    for (final item in templateItems) {
      // A category index from a newer schema falls outside the map built
      // above — same defensive stance as _categoryFromIndex.
      final sortOrder = nextSortOrder[item.category] ?? 0;
      nextSortOrder[item.category] = sortOrder + 1;
      rows.add(
        TripPackingItemRow(
          id: _idGen(),
          tripId: tripId,
          category: item.category,
          label: item.label,
          status: PackingItemStatus.toPack.index,
          sortOrder: sortOrder,
        ),
      );
    }
    await _dao.insertTripItems(rows);
  }

  /// The next free `sortOrder` at the end of one category's section:
  /// `max(existing) + 1`, or 0 when the category is empty. Deliberately not
  /// a count — deleting from the middle of a category would otherwise hand
  /// the next insert a `sortOrder` that is already in use, making the
  /// relative order of the two non-deterministic.
  int _nextSortOrder(Iterable<int> existingSortOrdersInCategory) {
    if (existingSortOrdersInCategory.isEmpty) return 0;
    return existingSortOrdersInCategory.reduce((a, b) => a > b ? a : b) + 1;
  }

  PackingTemplate _templateToDomain(PackingTemplateRow row) =>
      PackingTemplate(id: row.id, name: row.name);

  PackingTemplateItem _templateItemToDomain(PackingTemplateItemRow row) =>
      PackingTemplateItem(
        id: row.id,
        templateId: row.templateId,
        category: _categoryFromIndex(row.category),
        label: row.label,
        sortOrder: row.sortOrder,
      );

  TripPackingItem _tripItemToDomain(TripPackingItemRow row) => TripPackingItem(
        id: row.id,
        tripId: row.tripId,
        category: _categoryFromIndex(row.category),
        label: row.label,
        status: _statusFromIndex(row.status),
        sortOrder: row.sortOrder,
      );

  // Defensive: an index from a newer schema version falls back to a safe
  // default rather than throwing a RangeError on an old build (same
  // precedent as ExpenseRepository._toDomain).
  PackingCategory _categoryFromIndex(int index) =>
      index >= 0 && index < PackingCategory.values.length
          ? PackingCategory.values[index]
          : PackingCategory.other;

  PackingItemStatus _statusFromIndex(int index) =>
      index >= 0 && index < PackingItemStatus.values.length
          ? PackingItemStatus.values[index]
          : PackingItemStatus.toPack;
}
