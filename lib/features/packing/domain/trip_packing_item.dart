import 'package:flutter/foundation.dart';

import 'packing_category.dart';
import 'packing_item_status.dart';

@immutable
class TripPackingItem {
  const TripPackingItem({
    required this.id,
    required this.tripId,
    required this.category,
    required this.label,
    required this.status,
    required this.sortOrder,
  });

  final String id;
  final String tripId;
  final PackingCategory category;
  final String label;
  final PackingItemStatus status;
  final int sortOrder;

  TripPackingItem copyWith({String? label, PackingItemStatus? status}) =>
      TripPackingItem(
        id: id,
        tripId: tripId,
        category: category,
        label: label ?? this.label,
        status: status ?? this.status,
        sortOrder: sortOrder,
      );

  @override
  bool operator ==(Object other) =>
      other is TripPackingItem &&
      other.id == id &&
      other.tripId == tripId &&
      other.category == category &&
      other.label == label &&
      other.status == status &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode =>
      Object.hash(id, tripId, category, label, status, sortOrder);
}
