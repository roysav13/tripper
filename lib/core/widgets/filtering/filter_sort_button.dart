import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Small trigger for [showFilterSortSheet] — a plain icon button with a
/// coral dot badge when a filter is active, so the filter state stays
/// visible even while the sheet itself is closed. Generalized from the
/// original Places-only `PlaceFilterButton`. The button now also hosts
/// sort (via the same sheet), so it renders whenever the feature has more
/// than one sort option — not only when a facet has values — and the
/// badge itself reflects *filters* only (a non-default sort surfaces as
/// the strip's separate mono pill instead).
class FilterSortButton extends StatelessWidget {
  const FilterSortButton({
    super.key,
    required this.active,
    required this.onPressed,
  });

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.tune, color: colors.inkSecondary),
          tooltip: l10n.filterSortButtonTooltip,
          onPressed: onPressed,
        ),
        if (active)
          PositionedDirectional(
            top: 8,
            end: 8,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 8, height: 8),
              ),
            ),
          ),
      ],
    );
  }
}
