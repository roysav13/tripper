import 'dart:async';

import 'package:tripper/features/packing/data/packing_repository.dart';
import 'package:tripper/features/packing/domain/packing_category.dart';
import 'package:tripper/features/packing/domain/packing_item_status.dart';
import 'package:tripper/features/packing/domain/packing_template.dart';
import 'package:tripper/features/packing/domain/trip_packing_item.dart';

/// Fake at the repository boundary (testing rules — no DB in widget tests).
class FakePackingRepository implements PackingRepository {
  FakePackingRepository({
    List<PackingTemplate> templates = const [],
    List<PackingTemplateItem> templateItems = const [],
    List<TripPackingItem> tripItems = const [],
  })  : _templates = [...templates],
        _templateItems = [...templateItems],
        _tripItems = [...tripItems];

  final List<PackingTemplate> _templates;
  final List<PackingTemplateItem> _templateItems;
  final List<TripPackingItem> _tripItems;

  final _templatesController =
      StreamController<List<PackingTemplate>>.broadcast();
  final _templateItemsController =
      StreamController<List<PackingTemplateItem>>.broadcast();
  final _tripItemsController =
      StreamController<List<TripPackingItem>>.broadcast();
  var _idCounter = 0;

  void emitTripItemsError(Object error) => _tripItemsController.addError(error);

  @override
  Stream<List<PackingTemplate>> watchTemplates() async* {
    yield List.of(_templates);
    yield* _templatesController.stream;
  }

  @override
  Future<String> createTemplate({required String name}) async {
    final template = PackingTemplate(id: 'tpl-${_idCounter++}', name: name);
    _templates.add(template);
    _templatesController.add(List.of(_templates));
    return template.id;
  }

  @override
  Future<void> renameTemplate(String id, String name) async {
    final i = _templates.indexWhere((t) => t.id == id);
    if (i == -1) return;
    _templates[i] = _templates[i].copyWith(name: name);
    _templatesController.add(List.of(_templates));
  }

  @override
  Future<void> deleteTemplate(String id) async {
    _templates.removeWhere((t) => t.id == id);
    _templateItems.removeWhere((i) => i.templateId == id);
    _templatesController.add(List.of(_templates));
    _templateItemsController.add(List.of(_templateItems));
  }

  @override
  Stream<List<PackingTemplateItem>> watchTemplateItems(
    String templateId,
  ) async* {
    yield _templateItems.where((i) => i.templateId == templateId).toList();
    yield* _templateItemsController.stream.map(
      (_) => _templateItems.where((i) => i.templateId == templateId).toList(),
    );
  }

  @override
  Future<String> addTemplateItem({
    required String templateId,
    required PackingCategory category,
    required String label,
  }) async {
    final item = PackingTemplateItem(
      id: 'tpli-${_idCounter++}',
      templateId: templateId,
      category: category,
      label: label,
      sortOrder: _templateItems
          .where((i) => i.templateId == templateId && i.category == category)
          .length,
    );
    _templateItems.add(item);
    _templateItemsController.add(List.of(_templateItems));
    return item.id;
  }

  @override
  Future<void> updateTemplateItem(PackingTemplateItem item) async {
    final i = _templateItems.indexWhere((e) => e.id == item.id);
    if (i == -1) return;
    _templateItems[i] = item;
    _templateItemsController.add(List.of(_templateItems));
  }

  @override
  Future<void> deleteTemplateItem(String id) async {
    _templateItems.removeWhere((i) => i.id == id);
    _templateItemsController.add(List.of(_templateItems));
  }

  @override
  Stream<List<TripPackingItem>> watchTripItems(String tripId) async* {
    yield _tripItems.where((i) => i.tripId == tripId).toList();
    yield* _tripItemsController.stream
        .map((_) => _tripItems.where((i) => i.tripId == tripId).toList());
  }

  @override
  Future<String> addTripItem({
    required String tripId,
    required PackingCategory category,
    required String label,
  }) async {
    final item = TripPackingItem(
      id: 'i-${_idCounter++}',
      tripId: tripId,
      category: category,
      label: label,
      status: PackingItemStatus.toPack,
      sortOrder: _tripItems
          .where((i) => i.tripId == tripId && i.category == category)
          .length,
    );
    _tripItems.add(item);
    _tripItemsController.add(List.of(_tripItems));
    return item.id;
  }

  @override
  Future<void> updateTripItemLabel(String id, String label) async {
    final i = _tripItems.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _tripItems[i] = _tripItems[i].copyWith(label: label);
    _tripItemsController.add(List.of(_tripItems));
  }

  @override
  Future<void> updateTripItemStatus(
    String id,
    PackingItemStatus status,
  ) async {
    final i = _tripItems.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _tripItems[i] = _tripItems[i].copyWith(status: status);
    _tripItemsController.add(List.of(_tripItems));
  }

  @override
  Future<void> deleteTripItem(String id) async {
    _tripItems.removeWhere((i) => i.id == id);
    _tripItemsController.add(List.of(_tripItems));
  }

  @override
  Future<void> applyTemplate({
    required String tripId,
    required String templateId,
  }) async {
    final source = _templateItems.where((i) => i.templateId == templateId);
    for (final item in source) {
      _tripItems.add(
        TripPackingItem(
          id: 'i-${_idCounter++}',
          tripId: tripId,
          category: item.category,
          label: item.label,
          status: PackingItemStatus.toPack,
          sortOrder: _tripItems
              .where((i) => i.tripId == tripId && i.category == item.category)
              .length,
        ),
      );
    }
    _tripItemsController.add(List.of(_tripItems));
  }
}
