import 'package:flutter/material.dart';

import '../../filtering/facet.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../auto_direction_text.dart';
import '../mono_text.dart';

/// One active filter pill: which facet it belongs to, and the value
/// selected within it.
@immutable
class ActiveFilterEntry {
  const ActiveFilterEntry({required this.facetId, required this.value});

  final String facetId;
  final FacetValue value;
}

/// A horizontal strip of active-filter pills shown above a filtered
/// list/map, generalized from the original Places-only filter strip so
/// every feature reuses one widget. Renders nothing when there is nothing
/// active. Horizontally scrollable rather than wrapping, so an
/// active-heavy filter never pushes content down by more than one row's
/// height.
///
/// [sortLabel] renders a separate, non-removable mono pill when the
/// current sort differs from the feature's default — visually distinct
/// from the removable coral filter pills, since a sort is a *mode* and a
/// filter is a *subtraction*.
class ActiveFilterStrip extends StatelessWidget {
  const ActiveFilterStrip({
    super.key,
    required this.active,
    required this.onRemove,
    required this.onClearAll,
    this.sortLabel,
    this.onSortTap,
  });

  final List<ActiveFilterEntry> active;
  final void Function(String facetId, String valueId) onRemove;
  final VoidCallback onClearAll;
  final String? sortLabel;
  final VoidCallback? onSortTap;

  static const _height = 36.0;

  @override
  Widget build(BuildContext context) {
    if (active.isEmpty && sortLabel == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      height: _height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (sortLabel != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: _SortPill(label: sortLabel!, onTap: onSortTap),
            ),
          for (final entry in active)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: _FilterPill(
                label: entry.value.label,
                onRemove: () => onRemove(entry.facetId, entry.value.id),
              ),
            ),
          if (active.length > 1)
            Center(
              child: TextButton(
                onPressed: onClearAll,
                child: Text(l10n.filterClearAll),
              ),
            ),
        ],
      ),
    );
  }
}

/// One removable active-filter pill: label + a tappable close glyph, coral
/// outline on a solid surface (never a filled coral background — that's
/// reserved for the one true CTA per screen, the sheet's "Show N" button).
class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShape.pillRadius),
        side: BorderSide(color: colors.accent, width: AppShape.hairlineWidth),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShape.pillRadius),
        onTap: onRemove,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.md,
            end: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AutoDirectionText(
                label,
                style: AppTextStyles.label.copyWith(color: colors.accent),
              ),
              const SizedBox(width: 2),
              Icon(Icons.close, size: 14, color: colors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// The non-removable "a sort is active" pill — mono/uppercase, hairline
/// outline (never coral, which is reserved for filters), tap reopens the
/// sheet.
class _SortPill extends StatelessWidget {
  const _SortPill({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShape.pillRadius),
        side: BorderSide(color: colors.hairline, width: AppShape.hairlineWidth),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShape.pillRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
          ),
          child: SizedBox(
            height: 36,
            child: Center(child: MonoText(label)),
          ),
        ),
      ),
    );
  }
}
