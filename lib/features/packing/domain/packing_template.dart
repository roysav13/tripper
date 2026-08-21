import 'package:flutter/foundation.dart';

import 'packing_category.dart';

@immutable
class PackingTemplate {
  const PackingTemplate({required this.id, required this.name});

  final String id;
  final String name;

  PackingTemplate copyWith({String? name}) =>
      PackingTemplate(id: id, name: name ?? this.name);

  @override
  bool operator ==(Object other) =>
      other is PackingTemplate && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

@immutable
class PackingTemplateItem {
  const PackingTemplateItem({
    required this.id,
    required this.templateId,
    required this.category,
    required this.label,
    required this.sortOrder,
  });

  final String id;
  final String templateId;
  final PackingCategory category;
  final String label;

  /// Position within this item's category section. Assigned on insert by
  /// the repository (append-to-end); not user-reorderable in this round.
  final int sortOrder;

  PackingTemplateItem copyWith({PackingCategory? category, String? label}) =>
      PackingTemplateItem(
        id: id,
        templateId: templateId,
        category: category ?? this.category,
        label: label ?? this.label,
        sortOrder: sortOrder,
      );

  @override
  bool operator ==(Object other) =>
      other is PackingTemplateItem &&
      other.id == id &&
      other.templateId == templateId &&
      other.category == category &&
      other.label == label &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(id, templateId, category, label, sortOrder);
}
