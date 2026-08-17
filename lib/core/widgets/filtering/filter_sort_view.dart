import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../filtering/filter_engine.dart';
import '../../filtering/filter_sort_config.dart';
import '../../filtering/filter_sort_controller.dart';
import '../../filtering/sort_option.dart';

/// Owns the shared prune -> filter -> sort pipeline so every feature stops
/// hand-copying it. Resolves [scope] against [controllerFamily] and
/// [itemsProvider], prunes any stale selection (deferred to a post-frame
/// callback since mutating provider state during build throws), applies
/// [config]'s facets, then its active sort, and hands the result to
/// [builder].
///
/// [builder] receives the unfiltered [all] list too, since some features
/// need both (e.g. an empty-state branch that distinguishes "no data at
/// all" from "filtered to nothing").
class FilterSortView<T, F extends Enum> extends ConsumerWidget {
  const FilterSortView({
    super.key,
    required this.itemsProvider,
    required this.controllerFamily,
    required this.scope,
    required this.config,
    required this.builder,
  });

  final ProviderListenable<AsyncValue<List<T>>> itemsProvider;
  final NotifierProviderFamily<FilterSortController<F>, FilterSortState<F>,
      String> controllerFamily;
  final String scope;
  final FilterSortConfig<T, F> config;
  final Widget Function(
    BuildContext context,
    List<T> all,
    List<T> visible,
    FilterSortState<F> state,
  ) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = controllerFamily(scope);
    final all = ref.watch(itemsProvider).valueOrNull ?? <T>[];
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    final pruned = pruneSelection(all, config.facets, state.selection);
    if (!identical(pruned, state.selection)) {
      // Mutating provider state synchronously inside build() throws —
      // defer to after this frame completes. `notifier` (not `ref`) is
      // captured, so this stays safe even if this widget is disposed
      // before the callback fires — the controller outlives the widget.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.setSelection(pruned);
      });
    }

    final filtered = applyFilter(all, config.facets, pruned);
    final visible = applySort(filtered, state.sort, config.sortOptions);

    return builder(
      context,
      all,
      visible,
      FilterSortState(selection: pruned, sort: state.sort),
    );
  }
}
