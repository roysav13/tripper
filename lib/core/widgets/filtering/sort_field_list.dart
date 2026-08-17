import 'package:flutter/material.dart';

import '../../filtering/sort_option.dart';
import '../../filtering/sort_spec.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../mono_text.dart';

/// One row per sort field. The selected row shows a coral check, the
/// current direction's label in mono, and a direction arrow — unless the
/// option is [SortOption.directional] `false`, which never shows an
/// arrow. Tapping any row (selected or not) reports that row's field;
/// deciding whether that's a fresh selection or a direction flip is the
/// controller's job ([FilterSortController.selectSortField]), not this
/// widget's.
class SortFieldList<T, F extends Enum> extends StatelessWidget {
  const SortFieldList({
    super.key,
    required this.options,
    required this.current,
    required this.onSelect,
    this.subtitleOf,
  });

  final List<SortOption<T, F>> options;
  final SortSpec<F> current;
  final void Function(F field) onSelect;

  /// Optional per-row status line rendered under a field's label — e.g.
  /// Places uses this to show "Fetching your location…" under Distance
  /// while a GPS fix is pending. Null (the default) renders nothing;
  /// most features never set this.
  final Widget? Function(F field)? subtitleOf;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final option in options)
          InkWell(
            onTap: () => onSelect(option.field),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: option.field == current.field
                            ? Icon(Icons.check, color: colors.accent, size: 20)
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          option.label,
                          style: AppTextStyles.body.copyWith(
                            color: colors.inkPrimary,
                          ),
                        ),
                      ),
                      if (option.field == current.field) ...[
                        MonoText(
                          current.direction == SortDirection.ascending
                              ? option.ascendingLabel
                              : option.descendingLabel,
                        ),
                        if (option.directional) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Icon(
                            current.direction == SortDirection.ascending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 16,
                            color: colors.inkMuted,
                          ),
                        ],
                      ],
                    ],
                  ),
                  if (subtitleOf?.call(option.field) case final subtitle?)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 28,
                        top: 2,
                      ),
                      child: subtitle,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
