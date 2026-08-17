import 'package:flutter/material.dart';

import '../../filtering/facet.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../auto_direction_text.dart';
import '../mono_text.dart';

/// An unbounded facet's values as a searchable single-column checklist —
/// suits a large, dynamic set (countries, user-made lists) that would
/// otherwise degrade into an unpredictable wall of chips. Generalized from
/// the original Places filter sheet's country checklist. The search box
/// only appears once [values] exceeds [searchThreshold].
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
    final colors = context.colors;
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
          for (final value in visible)
            InkWell(
              onTap: () {
                final next = widget.selected.contains(value.id)
                    ? widget.selected.where((id) => id != value.id).toSet()
                    : {...widget.selected, value.id};
                widget.onChanged(next);
              },
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AutoDirectionText(
                        value.label,
                        style: AppTextStyles.body
                            .copyWith(color: colors.inkPrimary),
                      ),
                    ),
                    if (widget.selected.contains(value.id))
                      Icon(Icons.check, color: colors.accent, size: 20),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
