import 'package:flutter/material.dart';

import '../../filtering/facet.dart';
import '../../theme/app_spacing.dart';
import '../mono_text.dart';
import '../pill_chip.dart';

/// An unbounded facet's values as a searchable [Wrap] of [PillChip]s —
/// suits a large, dynamic set (countries, user-made lists) that would
/// otherwise degrade into an unpredictable wall of text rows. Same chip
/// widget [FacetChipWrap] uses, so every facet in the sheet reads as one
/// consistent control. The search box only appears once [values] exceeds
/// [searchThreshold].
class FacetChecklist extends StatefulWidget {
  const FacetChecklist({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.searchHint,
    required this.noResultsLabel,
    this.searchThreshold = kFacetSearchThreshold,
  });

  final List<FacetValue> values;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final String searchHint;
  final String noResultsLabel;
  final int searchThreshold;

  @override
  State<FacetChecklist> createState() => _FacetChecklistState();
}

class _FacetChecklistState extends State<FacetChecklist> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? widget.values
        : widget.values
            .where((v) => v.label.toLowerCase().contains(query))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.values.length > widget.searchThreshold)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
              ),
            ),
          ),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.md,
            ),
            child: MonoText(widget.noResultsLabel, muted: true),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final value in visible)
                PillChip(
                  label: value.label,
                  selected: widget.selected.contains(value.id),
                  onTap: () {
                    final next = widget.selected.contains(value.id)
                        ? widget.selected.where((id) => id != value.id).toSet()
                        : {...widget.selected, value.id};
                    widget.onChanged(next);
                  },
                ),
            ],
          ),
      ],
    );
  }
}
