import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'auto_direction_text.dart';

/// The one chip visual language used throughout the app — a hairline
/// outline pill that fills coral (border + label) when [selected]. Shared
/// by the filter sheet's facet values (chips and checklist alike, so
/// Category/Country/Lists all read as the same control), and by
/// non-interactive tags like a place row's category badge (omit [onTap]).
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = selected ? colors.accent : colors.inkPrimary;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShape.pillRadius),
        side: BorderSide(
          color: selected ? colors.accent : colors.hairline,
          width: AppShape.hairlineWidth,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShape.pillRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: tint),
                const SizedBox(width: AppSpacing.xs),
              ],
              AutoDirectionText(
                label,
                style: AppTextStyles.label.copyWith(color: tint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
