import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/app_database.dart';
import 'package:tripper/features/packing/data/packing_repository.dart';
import 'package:tripper/features/packing/domain/packing_category.dart';
import 'package:tripper/features/packing/domain/packing_item_status.dart';
import 'package:tripper/features/trips/data/trip_repository.dart';

void main() {
  late AppDatabase db;
  late DriftPackingRepository repo;
  late DriftTripRepository tripRepo;
  var idCounter = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    idCounter = 0;
    repo = DriftPackingRepository(db.packingDao, () => 'id-${idCounter++}');
    tripRepo = DriftTripRepository(db.tripsDao, () => DateTime(2026, 8, 22));
  });

  tearDown(() => db.close());

  Future<String> createTrip() => tripRepo.createTrip(
        name: 'Thailand',
        destinations: ['Krabi'],
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 14),
        colorTag: 0,
      );

  test('creating a template makes it appear in watchTemplates', () async {
    await repo.createTemplate(name: 'Beach trip');
    final templates = await repo.watchTemplates().first;
    expect(templates.single.name, 'Beach trip');
  });

  test('renaming a template updates it in place', () async {
    final id = await repo.createTemplate(name: 'Beach trip');
    await repo.renameTemplate(id, 'Summer beach trip');
    final templates = await repo.watchTemplates().first;
    expect(templates.single.name, 'Summer beach trip');
  });

  test('deleting a template removes it', () async {
    final id = await repo.createTemplate(name: 'Beach trip');
    await repo.deleteTemplate(id);
    expect(await repo.watchTemplates().first, isEmpty);
  });

  test('template items are returned for their own template only', () async {
    final tplA = await repo.createTemplate(name: 'A');
    final tplB = await repo.createTemplate(name: 'B');
    await repo.addTemplateItem(
      templateId: tplA,
      category: PackingCategory.clothing,
      label: 'Shirt',
    );
    await repo.addTemplateItem(
      templateId: tplB,
      category: PackingCategory.documents,
      label: 'Passport',
    );

    final itemsA = await repo.watchTemplateItems(tplA).first;
    expect(itemsA, hasLength(1));
    expect(itemsA.single.label, 'Shirt');
  });

  test('a trip item defaults to toPack status', () async {
    final tripId = await createTrip();
    await repo.addTripItem(
      tripId: tripId,
      category: PackingCategory.clothing,
      label: 'Black shirt',
    );
    final items = await repo.watchTripItems(tripId).first;
    expect(items.single.status, PackingItemStatus.toPack);
  });

  test('a status update can jump directly from worn to clean', () async {
    final tripId = await createTrip();
    final id = await repo.addTripItem(
      tripId: tripId,
      category: PackingCategory.clothing,
      label: 'Black shirt',
    );
    await repo.updateTripItemStatus(id, PackingItemStatus.worn);
    await repo.updateTripItemStatus(id, PackingItemStatus.clean);

    final items = await repo.watchTripItems(tripId).first;
    expect(items.single.status, PackingItemStatus.clean);
  });

  test(
      'applyTemplate copies every item into the trip list, each starting '
      'at toPack', () async {
    final tripId = await createTrip();
    final templateId = await repo.createTemplate(name: 'Beach trip');
    await repo.addTemplateItem(
      templateId: templateId,
      category: PackingCategory.clothing,
      label: 'Swimsuit',
    );
    await repo.addTemplateItem(
      templateId: templateId,
      category: PackingCategory.documents,
      label: 'Passport',
    );

    await repo.applyTemplate(tripId: tripId, templateId: templateId);

    final tripItems = await repo.watchTripItems(tripId).first;
    expect(tripItems, hasLength(2));
    expect(tripItems.map((i) => i.label), containsAll(['Swimsuit', 'Passport']));
    expect(tripItems.every((i) => i.status == PackingItemStatus.toPack), isTrue);
  });

  test(
      'the trip list is independent of the template afterward — editing '
      'the template item does not change the already-copied trip item',
      () async {
    final tripId = await createTrip();
    final templateId = await repo.createTemplate(name: 'Beach trip');
    final templateItemId = await repo.addTemplateItem(
      templateId: templateId,
      category: PackingCategory.clothing,
      label: 'Swimsuit',
    );
    await repo.applyTemplate(tripId: tripId, templateId: templateId);

    final templateItems = await repo.watchTemplateItems(templateId).first;
    await repo.updateTemplateItem(
      templateItems.single.copyWith(label: 'Two swimsuits'),
    );

    final tripItems = await repo.watchTripItems(tripId).first;
    expect(tripItems.single.label, 'Swimsuit'); // unchanged
    expect(templateItemId, isNotEmpty); // sanity: id was actually used
  });

  test('applying the same template twice duplicates its items (append, '
      'not replace)', () async {
    final tripId = await createTrip();
    final templateId = await repo.createTemplate(name: 'Beach trip');
    await repo.addTemplateItem(
      templateId: templateId,
      category: PackingCategory.clothing,
      label: 'Swimsuit',
    );

    await repo.applyTemplate(tripId: tripId, templateId: templateId);
    await repo.applyTemplate(tripId: tripId, templateId: templateId);

    final tripItems = await repo.watchTripItems(tripId).first;
    expect(tripItems, hasLength(2));
  });

  test('deleting a trip cascades its packing items', () async {
    final tripId = await createTrip();
    await repo.addTripItem(
      tripId: tripId,
      category: PackingCategory.other,
      label: 'Charger',
    );
    await tripRepo.deleteTrip(tripId);
    expect(await repo.watchTripItems(tripId).first, isEmpty);
  });

  test('deleting a trip item removes it', () async {
    final tripId = await createTrip();
    final id = await repo.addTripItem(
      tripId: tripId,
      category: PackingCategory.other,
      label: 'Charger',
    );
    await repo.deleteTripItem(id);
    expect(await repo.watchTripItems(tripId).first, isEmpty);
  });

  test('updateTripItemLabel renames in place and changes nothing else',
      () async {
    final tripId = await createTrip();
    final id = await repo.addTripItem(
      tripId: tripId,
      category: PackingCategory.clothing,
      label: 'Shirt',
    );
    await repo.updateTripItemStatus(id, PackingItemStatus.worn);
    final before = (await repo.watchTripItems(tripId).first).single;

    await repo.updateTripItemLabel(id, 'Black shirt');

    final after = (await repo.watchTripItems(tripId).first).single;
    expect(after.label, 'Black shirt');
    expect(after.id, before.id);
    expect(after.tripId, before.tripId);
    expect(after.category, before.category);
    expect(after.status, before.status); // still worn, not reset
    expect(after.sortOrder, before.sortOrder);
  });

  test('updateTemplateItem preserves the item\'s sortOrder', () async {
    final templateId = await repo.createTemplate(name: 'Beach trip');
    await repo.addTemplateItem(
      templateId: templateId,
      category: PackingCategory.clothing,
      label: 'Shirt',
    );
    final secondId = await repo.addTemplateItem(
      templateId: templateId,
      category: PackingCategory.clothing,
      label: 'Shorts',
    );

    final second = (await repo.watchTemplateItems(templateId).first)
        .firstWhere((i) => i.id == secondId);
    expect(second.sortOrder, 1); // sanity: the two differ

    await repo.updateTemplateItem(second.copyWith(label: 'Swim shorts'));

    final updated = (await repo.watchTemplateItems(templateId).first)
        .firstWhere((i) => i.id == secondId);
    expect(updated.label, 'Swim shorts');
    expect(updated.sortOrder, 1); // not reset to 0 or some default
  });

  test('deleting a template item removes it', () async {
    final templateId = await repo.createTemplate(name: 'Beach trip');
    final id = await repo.addTemplateItem(
      templateId: templateId,
      category: PackingCategory.clothing,
      label: 'Swimsuit',
    );
    await repo.deleteTemplateItem(id);
    expect(await repo.watchTemplateItems(templateId).first, isEmpty);
  });

  test(
      'applying a template into an already-populated category appends with '
      'distinct, ordered sortOrders', () async {
    final tripId = await createTrip();
    await repo.addTripItem(
      tripId: tripId,
      category: PackingCategory.clothing,
      label: 'Shirt',
    );

    final templateId = await repo.createTemplate(name: 'Beach trip');
    await repo.addTemplateItem(
      templateId: templateId,
      category: PackingCategory.clothing,
      label: 'Swimsuit',
    );
    await repo.addTemplateItem(
      templateId: templateId,
      category: PackingCategory.clothing,
      label: 'Sandals',
    );

    await repo.applyTemplate(tripId: tripId, templateId: templateId);

    final clothing = (await repo.watchTripItems(tripId).first)
        .where((i) => i.category == PackingCategory.clothing)
        .toList();
    expect(clothing, hasLength(3));
    // watchTripItems orders by sortOrder, so this is both the values and
    // the resulting on-screen order.
    expect(clothing.map((i) => i.sortOrder), [0, 1, 2]);
    expect(clothing.map((i) => i.label), ['Shirt', 'Swimsuit', 'Sandals']);
  });

  test(
      'deleting from the middle of a category does not hand the next insert '
      'a sortOrder that is already in use', () async {
    final tripId = await createTrip();
    final first = await repo.addTripItem(
      tripId: tripId,
      category: PackingCategory.clothing,
      label: 'Shirt',
    );
    await repo.addTripItem(
      tripId: tripId,
      category: PackingCategory.clothing,
      label: 'Shorts',
    );
    await repo.deleteTripItem(first); // frees sortOrder 0, leaves 1 in use

    await repo.addTripItem(
      tripId: tripId,
      category: PackingCategory.clothing,
      label: 'Hat',
    );

    final sortOrders =
        (await repo.watchTripItems(tripId).first).map((i) => i.sortOrder);
    expect(sortOrders.toSet(), hasLength(sortOrders.length));
    expect(sortOrders, [1, 2]); // max + 1, not a re-used count
  });
}
