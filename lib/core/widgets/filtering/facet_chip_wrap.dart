import 'package:flutter/material.dart';

import '../../filtering/facet.dart';
import '../../theme/app_spacing.dart';
import '../pill_chip.dart';

/// A bounded facet's values as a `Wrap` of [PillChip]s — suits a small,
/// fixed set (e.g. 12 place categories). Same chip widget as
/// [FacetChecklist] uses for its own values, so every facet in the sheet
/// reads as one consistent control regardless of presentation.
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
          PillChip(
            label: value.label,
            icon: iconOf?.call(value.id),
            selected: selected.contains(value.id),
            onTap: () => onToggle(value.id, !selected.contains(value.id)),
          ),
      ],
    );
  }
}
