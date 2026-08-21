import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/packing/domain/packing_category.dart';
import 'package:tripper/features/packing/domain/packing_item_status.dart';
import 'package:tripper/features/packing/domain/trip_packing_item.dart';

void main() {
  const item = TripPackingItem(
    id: 'i1',
    tripId: 't1',
    category: PackingCategory.clothing,
    label: 'Black shirt',
    status: PackingItemStatus.toPack,
    sortOrder: 0,
  );

  test('two items with identical fields are equal', () {
    const other = TripPackingItem(
      id: 'i1',
      tripId: 't1',
      category: PackingCategory.clothing,
      label: 'Black shirt',
      status: PackingItemStatus.toPack,
      sortOrder: 0,
    );
    expect(item, other);
    expect(item.hashCode, other.hashCode);
  });

  test('copyWith changes only the given fields', () {
    final updated = item.copyWith(status: PackingItemStatus.worn);
    expect(updated.status, PackingItemStatus.worn);
    expect(updated.label, item.label);
    expect(updated.id, item.id);
  });

  test('copyWith with no arguments returns an equal item', () {
    expect(item.copyWith(), item);
  });

  test('status can jump non-adjacent states via copyWith, e.g. worn to clean',
      () {
    final clean = item
        .copyWith(status: PackingItemStatus.worn)
        .copyWith(status: PackingItemStatus.clean);
    expect(clean.status, PackingItemStatus.clean);
  });
}
