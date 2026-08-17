import 'package:flutter/foundation.dart';

import 'facet.dart';
import 'sort_option.dart';
import 'sort_spec.dart';

/// Everything a [FilterSortView] needs to drive one feature's filter+sort
/// sheet: which facets are filterable, which fields are sortable, the
/// default sort, and how to phrase the result count on the sheet's CTA
/// (e.g. "Show 3 places" vs. "Show 3 documents" — the one genuinely
/// feature-owned string in an otherwise shared sheet).
@immutable
class FilterSortConfig<T, F extends Enum> {
  const FilterSortConfig({
    required this.facets,
    required this.sortOptions,
    required this.defaultSort,
    required this.resultLabel,
  });

  final List<Facet<T>> facets;
  final List<SortOption<T, F>> sortOptions;
  final SortSpec<F> defaultSort;
  final String Function(int count) resultLabel;
}
