import 'package:flutter/material.dart';

import '../../filtering/facet.dart';
import '../../theme/app_spacing.dart';

/// A bounded facet's values as a `Wrap` of Material [FilterChip]s — suits
/// a small, fixed set (e.g. 12 place categories). Generalized from the
/// original Places filter sheet's inline category chip grid.
class FacetChipWrap extends StatelessWidget {
  const FacetChipWrap({
    super.key,
    required this.values,
    required this.selected,
    required this.onToggle,
    this.iconOf,
  });

  final List<FacetValue> values;
  final Set<String> selected;
  final void Function(String valueId, bool selected) onToggle;
  final IconData? Function(String valueId)? iconOf;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final value in values)
          FilterChip(
            avatar: () {
              final icon = iconOf?.call(value.id);
              return icon == null ? null : Icon(icon, size: 16);
            }(),
            label: Text(value.label),
            selected: selected.contains(value.id),
            onSelected: (next) => onToggle(value.id, next),
          ),
      ],
    );
  }
}
