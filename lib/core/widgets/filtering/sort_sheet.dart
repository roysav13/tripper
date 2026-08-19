import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../filtering/filter_sort_config.dart';
import '../../filtering/filter_sort_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import 'sort_field_list.dart';

/// Opens the generic sort sheet — a solid, non-glass modal bottom sheet
/// (redesign spec §5's glass carve-out names only the filter sheet, so
/// sort stays a regular solid surface, hard rule 6) shared by every
/// feature that sorts a list. Filtering has its own trigger and sheet —
/// see `filter_sheet.dart`.
Future<void> showSortSheet<T, F extends Enum>(
  BuildContext context, {
  required NotifierProviderFamily<FilterSortController<F>, FilterSortState<F>,
          String>
      controllerFamily,
  required String scope,
  required FilterSortConfig<T, F> config,
  Widget? Function(BuildContext context, WidgetRef ref, F field)?
      sortSubtitleBuilder,
}) {
  final provider = controllerFamily(scope);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _SortSheet<T, F>(
      stateProvider: provider,
      notifierOf: (ref) => ref.read(provider.notifier),
      config: config,
      sortSubtitleBuilder: sortSubtitleBuilder,
    ),
  );
}

class _SortSheet<T, F extends Enum> extends ConsumerWidget {
  const _SortSheet({
    required this.stateProvider,
    required this.notifierOf,
    required this.config,
    this.sortSubtitleBuilder,
  });

  final ProviderListenable<FilterSortState<F>> stateProvider;
  final FilterSortController<F> Function(WidgetRef ref) notifierOf;
  final FilterSortConfig<T, F> config;

  /// Optional per-row status line under a sort option, e.g. Places'
  /// location-fetch status under Distance — see [SortFieldList.subtitleOf].
  final Widget? Function(BuildContext context, WidgetRef ref, F field)?
      sortSubtitleBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final state = ref.watch(stateProvider);
    final notifier = notifierOf(ref);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppShape.radius),
          ),
          side:
              BorderSide(color: colors.hairline, width: AppShape.hairlineWidth),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.sortSheetTitle,
                        style: AppTextStyles.title.copyWith(
                          color: colors.inkPrimary,
                        ),
                      ),
                    ),
                    const _SheetCloseButton(),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: SingleChildScrollView(
                    child: SortFieldList<T, F>(
                      options: config.sortOptions,
                      current: state.sort,
                      onSelect: (field) {
                        final option = config.sortOptions
                            .firstWhere((o) => o.field == field);
                        notifier.selectSortField(
                          field,
                          option.defaultDirection,
                        );
                      },
                      subtitleOf: sortSubtitleBuilder == null
                          ? null
                          : (field) =>
                              sortSubtitleBuilder!(context, ref, field),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small bordered close glyph shared by the filter and sort sheets — a
/// rounded-square hairline outline around an X, matching the reference's
/// close control (redesign spec §5).
class _SheetCloseButton extends StatelessWidget {
  const _SheetCloseButton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        side: BorderSide(color: colors.hairline, width: AppShape.hairlineWidth),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        onTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Icon(Icons.close, size: 18, color: colors.inkSecondary),
        ),
      ),
    );
  }
}
