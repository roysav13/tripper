import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'filter_selection.dart';
import 'sort_spec.dart';

/// The current filter + sort picks for one scope of one feature.
@immutable
class FilterSortState<F extends Enum> {
  const FilterSortState({required this.selection, required this.sort});

  final FilterSelection selection;
  final SortSpec<F> sort;

  FilterSortState<F> copyWith({
    FilterSelection? selection,
    SortSpec<F>? sort,
  }) =>
      FilterSortState(
        selection: selection ?? this.selection,
        sort: sort ?? this.sort,
      );

  @override
  bool operator ==(Object other) =>
      other is FilterSortState<F> &&
      other.selection == selection &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(selection, sort);
}

/// Generic filter+sort state per scope. Each feature instantiates one
/// `NotifierProvider.family` from this, keyed by a scope string
/// (`'places'`, `'trip:<id>'`, ...) so independent surfaces (an app-wide
/// tab and a per-trip tab) keep independent filter/sort state without any
/// feature writing its own notifier.
class FilterSortController<F extends Enum>
    extends FamilyNotifier<FilterSortState<F>, String> {
  FilterSortController(this._defaultSort);

  final SortSpec<F> _defaultSort;

  @override
  FilterSortState<F> build(String arg) => FilterSortState(
        selection: FilterSelection.empty,
        sort: _defaultSort,
      );

  void toggleValue(String facetId, String valueId) {
    state = state.copyWith(selection: state.selection.toggle(facetId, valueId));
  }

  void removeValue(String facetId, String valueId) {
    state = state.copyWith(selection: state.selection.remove(facetId, valueId));
  }

  void setFacetValues(String facetId, Set<String> values) {
    state =
        state.copyWith(selection: state.selection.withValues(facetId, values));
  }

  void clearFilters() {
    state = state.copyWith(selection: FilterSelection.empty);
  }

  /// Selects [field] at [defaultDirection] if a different field is
  /// currently active; flips direction if [field] is already the active
  /// sort field.
  void selectSortField(F field, SortDirection defaultDirection) {
    state = state.copyWith(
      sort: state.sort.field == field
          ? state.sort.flipped()
          : SortSpec(field, defaultDirection),
    );
  }

  /// Used by [FilterSortView]'s prune step — a no-op (no state write) when
  /// [selection] is unchanged, so pruning a clean selection never triggers
  /// a rebuild.
  void setSelection(FilterSelection selection) {
    if (selection == state.selection) return;
    state = state.copyWith(selection: selection);
  }
}
