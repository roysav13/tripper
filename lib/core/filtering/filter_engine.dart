import 'facet.dart';
import 'filter_selection.dart';

/// Items matching [selection]: AND across facets, OR within a facet. An
/// empty selection for a facet means that facet doesn't filter at all. An
/// item with no value in a facet never matches a non-empty selection for
/// that facet. Pure — unit-tested without widgets.
List<T> applyFilter<T>(
  List<T> items,
  List<Facet<T>> facets,
  FilterSelection selection,
) {
  if (selection.isEmpty) return items;
  return [
    for (final item in items)
      if (_matches(item, facets, selection)) item,
  ];
}

bool _matches<T>(T item, List<Facet<T>> facets, FilterSelection selection) {
  for (final facet in facets) {
    final selected = selection.valuesFor(facet.id);
    if (selected.isEmpty) continue;
    final itemValues = {for (final v in facet.valuesOf(item)) v.id};
    if (itemValues.intersection(selected).isEmpty) return false;
  }
  return true;
}

/// The distinct values [facet] contributes across [items], deduped by id
/// and ordered by [FacetValue.sortKey].
List<FacetValue> availableFacetValues<T>(List<T> items, Facet<T> facet) {
  final byId = <String, FacetValue>{};
  for (final item in items) {
    for (final value in facet.valuesOf(item)) {
      byId[value.id] = value;
    }
  }
  return byId.values.toList()..sort((a, b) => a.sortKey.compareTo(b.sortKey));
}

int filterMatchCount<T>(
  List<T> items,
  List<Facet<T>> facets,
  FilterSelection selection,
) =>
    applyFilter(items, facets, selection).length;

/// Drops any selected value id that no longer appears in [items] for its
/// facet, and drops an unknown facet id entirely. Returns the *identical*
/// [selection] instance when nothing was stale, so callers can cheaply
/// detect "did anything change" with `identical()` rather than a length
/// comparison.
FilterSelection pruneSelection<T>(
  List<T> items,
  List<Facet<T>> facets,
  FilterSelection selection,
) {
  var result = selection;
  var changed = false;
  for (final facetId in selection.byFacet.keys) {
    Facet<T>? facet;
    for (final f in facets) {
      if (f.id == facetId) {
        facet = f;
        break;
      }
    }
    if (facet == null) {
      result = result.clearFacet(facetId);
      changed = true;
      continue;
    }
    final available = {
      for (final v in availableFacetValues(items, facet)) v.id,
    };
    final selected = result.valuesFor(facetId);
    final pruned = selected.intersection(available);
    if (pruned.length != selected.length) {
      result = result.withValues(facetId, pruned);
      changed = true;
    }
  }
  return changed ? result : selection;
}
