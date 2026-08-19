import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../filtering/facet.dart';
import '../../filtering/filter_engine.dart';
import '../../filtering/filter_sort_config.dart';
import '../../filtering/filter_sort_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../glass_chrome.dart';
import '../section_label.dart';
import 'facet_checklist.dart';
import 'facet_chip_wrap.dart';

/// Opens the generic filter sheet — a glass-chrome modal bottom sheet
/// (redesign spec §5, the one sheet CLAUDE.md's hard rule 6 explicitly
/// names glass) shared by every feature that filters a list. Sorting has
/// its own trigger and sheet — see `sort_sheet.dart` — so this one is
/// filters only. [itemsProvider] is watched *inside* the sheet (not passed
/// as a static snapshot) so a facet whose last matching item is
/// edited/deleted away while the sheet is open still disappears live.
Future<void> showFilterSheet<T, F extends Enum>(
  BuildContext context, {
  required ProviderListenable<AsyncValue<List<T>>> itemsProvider,
  required NotifierProviderFamily<FilterSortController<F>, FilterSortState<F>,
          String>
      controllerFamily,
  required String scope,
  required FilterSortConfig<T, F> config,
}) {
  final provider = controllerFamily(scope);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _FilterSheet<T, F>(
      itemsProvider: itemsProvider,
      stateProvider: provider,
      notifierOf: (ref) => ref.read(provider.notifier),
      config: config,
    ),
  );
}

class _FilterSheet<T, F extends Enum> extends ConsumerWidget {
  const _FilterSheet({
    required this.itemsProvider,
    required this.stateProvider,
    required this.notifierOf,
    required this.config,
  });

  final ProviderListenable<AsyncValue<List<T>>> itemsProvider;
  final ProviderListenable<FilterSortState<F>> stateProvider;
  final FilterSortController<F> Function(WidgetRef ref) notifierOf;
  final FilterSortConfig<T, F> config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final items = ref.watch(itemsProvider).valueOrNull ?? <T>[];
    final state = ref.watch(stateProvider);
    final notifier = notifierOf(ref);
    final matchCount = filterMatchCount(items, config.facets, state.selection);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GlassChrome(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppShape.radius),
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
                        l10n.filterSheetTitle,
                        style: AppTextStyles.title.copyWith(
                          color: colors.inkPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: state.selection.isEmpty
                          ? null
                          : notifier.clearFilters,
                      child: Text(l10n.filterClearAction),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const _SheetCloseButton(),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < config.facets.length; i++)
                          _FacetSection<T, F>(
                            facet: config.facets[i],
                            items: items,
                            selected:
                                state.selection.valuesFor(config.facets[i].id),
                            onToggle: (valueId) => notifier.toggleValue(
                              config.facets[i].id,
                              valueId,
                            ),
                            onChanged: (values) => notifier.setFacetValues(
                              config.facets[i].id,
                              values,
                            ),
                            spacingBefore: i > 0,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: colors.surface,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppShape.pillRadius),
                      ),
                    ),
                    child: Text(config.resultLabel(matchCount)),
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

class _FacetSection<T, F extends Enum> extends StatelessWidget {
  const _FacetSection({
    required this.facet,
    required this.items,
    required this.selected,
    required this.onToggle,
    required this.onChanged,
    required this.spacingBefore,
  });

  final Facet<T> facet;
  final List<T> items;
  final Set<String> selected;
  final void Function(String valueId) onToggle;
  final ValueChanged<Set<String>> onChanged;
  final bool spacingBefore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final available = availableFacetValues(items, facet);
    if (available.isEmpty) return const SizedBox.shrink();

    final presentation = facet.presentation == FacetPresentation.auto
        ? (available.length > facet.searchThreshold
            ? FacetPresentation.checklist
            : FacetPresentation.chips)
        : facet.presentation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (spacingBefore) ...[
          const SizedBox(height: AppSpacing.lg),
          Divider(
            height: 1,
            thickness: AppShape.hairlineWidth,
            color: colors.hairline,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        SectionLabel(facet.label, color: colors.inkPrimary),
        const SizedBox(height: AppSpacing.sm),
        if (presentation == FacetPresentation.chips)
          FacetChipWrap(
            values: available,
            selected: selected,
            onToggle: (valueId, _) => onToggle(valueId),
            iconOf: facet.iconOf,
          )
        else
          FacetChecklist(
            values: available,
            selected: selected,
            onChanged: onChanged,
            searchHint: facet.searchHint ?? '',
            noResultsLabel: facet.noResultsLabel ?? '',
            searchThreshold: facet.searchThreshold,
          ),
      ],
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
