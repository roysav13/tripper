import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';

/// Trigger for [showFilterSheet] — a labeled pill with a coral dot badge
/// when a filter is active, so the filter state stays visible even while
/// the sheet itself is closed. A labeled pill (not a bare AppBar icon) so
/// it never has to compete with the screen's own large serif title for
/// AppBar width — it lives in its own row in the body instead.
class FilterButton extends StatelessWidget {
  const FilterButton({
    super.key,
    required this.active,
    required this.onPressed,
  });

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _FilterSortPill(
      icon: Icons.tune,
      label: l10n.filterButtonTooltip,
      active: active,
      onPressed: onPressed,
    );
  }
}

/// Trigger for [showSortSheet] — a labeled pill. No active-state badge:
/// unlike a filter (a subtraction from the list), a sort is always "on" at
/// some value, and the active-filter strip's separate mono pill already
/// surfaces a non-default sort where one is in view.
class SortButton extends StatelessWidget {
  const SortButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _FilterSortPill(
      icon: Icons.swap_vert,
      label: l10n.sortButtonTooltip,
      active: false,
      onPressed: onPressed,
    );
  }
}

class _FilterSortPill extends StatelessWidget {
  const _FilterSortPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppShape.pillRadius),
            side: BorderSide(
              color: colors.hairline,
              width: AppShape.hairlineWidth,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppShape.pillRadius),
            onTap: onPressed,
            child: ConstrainedBox(
              // Minimum 48x48 tap target (WCAG 2.5.5 / Android a11y
              // guidance) — the pill would otherwise read as a slender
              // ~34px-tall control, well under that floor.
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: colors.inkSecondary),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        label,
                        style: AppTextStyles.label.copyWith(
                          color: colors.inkPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (active)
          PositionedDirectional(
            top: -2,
            end: -2,
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
