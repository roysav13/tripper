import 'package:flutter/foundation.dart';

/// The user's current filter picks, generic across every feature that uses
/// the filter/sort core. Keyed by [Facet.id] -> the set of selected
/// [FacetValue.id]s for that facet.
///
/// Invariant: a facet key is never present with an empty value set — every
/// mutation that would empty a facet drops the key entirely, so
/// `byFacet.isEmpty == isEmpty` always holds and equality stays canonical.
@immutable
class FilterSelection {
  const FilterSelection([this.byFacet = const {}]);

  static const FilterSelection empty = FilterSelection();

  final Map<String, Set<String>> byFacet;

  bool get isEmpty => byFacet.isEmpty;

  /// Total number of selected values across every facet.
  int get activeCount =>
      byFacet.values.fold(0, (sum, values) => sum + values.length);

  Set<String> valuesFor(String facetId) => byFacet[facetId] ?? const {};

  /// Adds [valueId] if not selected, removes it if it is.
  FilterSelection toggle(String facetId, String valueId) {
    final current = valuesFor(facetId);
    return current.contains(valueId)
        ? remove(facetId, valueId)
        : withValues(facetId, {...current, valueId});
  }

  FilterSelection remove(String facetId, String valueId) {
    final current = valuesFor(facetId);
    if (!current.contains(valueId)) return this;
    final next = current.where((v) => v != valueId).toSet();
    return next.isEmpty ? clearFacet(facetId) : withValues(facetId, next);
  }

  FilterSelection withValues(String facetId, Set<String> values) {
    if (values.isEmpty) return clearFacet(facetId);
    return FilterSelection({...byFacet, facetId: values});
  }

  FilterSelection clearFacet(String facetId) {
    if (!byFacet.containsKey(facetId)) return this;
    final next = {...byFacet}..remove(facetId);
    return FilterSelection(next);
  }

  @override
  bool operator ==(Object other) {
    if (other is! FilterSelection) return false;
    if (byFacet.length != other.byFacet.length) return false;
    for (final entry in byFacet.entries) {
      final otherValues = other.byFacet[entry.key];
      if (otherValues == null || !setEquals(entry.value, otherValues)) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered([
        for (final entry in byFacet.entries)
          Object.hash(entry.key, Object.hashAllUnordered(entry.value)),
      ]);
}
