import 'package:flutter/widgets.dart';

/// One selectable value in a [Facet]. Equality is by [id] only, so a
/// value's label can be re-localized without breaking a stored selection.
@immutable
class FacetValue {
  const FacetValue({required this.id, required this.label, String? sortKey})
      : _sortKey = sortKey;

  final String id;
  final String label;
  final String? _sortKey;

  /// Orders values inside the filter sheet. Defaults to [label].
  String get sortKey => _sortKey ?? label;

  @override
  bool operator ==(Object other) => other is FacetValue && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// How a facet's values should render in the filter sheet.
enum FacetPresentation {
  /// A `Wrap` of chips — suits a small, bounded set of values.
  chips,

  /// A single-column checklist with a search box above [Facet.searchThreshold]
  /// values — suits an unbounded, user-authored set.
  checklist,

  /// Chips at or below [Facet.searchThreshold] available values, checklist
  /// above it.
  auto,
}

/// The country facet's search box appears once there are more than this
/// many available values — carried over from the original Places filter
/// sheet's threshold.
const int kFacetSearchThreshold = 6;

/// One filterable dimension over items of type [T].
///
/// [valuesOf] returns a *set*, so a many-to-many dimension (list
/// membership, tags) needs no separate abstraction: an item can belong to
/// several values of the same facet at once. An item with no value in this
/// dimension returns `const {}`, which never matches a non-empty selection.
@immutable
class Facet<T> {
  const Facet({
    required this.id,
    required this.label,
    required this.valuesOf,
    this.searchHint,
    this.noResultsLabel,
    this.presentation = FacetPresentation.auto,
    this.searchThreshold = kFacetSearchThreshold,
    this.iconOf,
  });

  /// Stable identifier used as the key in [FilterSelection.byFacet].
  final String id;

  /// Localized section title shown in the filter sheet.
  final String label;

  /// The set of values this facet contributes for one item.
  final Set<FacetValue> Function(T item) valuesOf;

  /// Localized search-box hint. Only used when the checklist presentation
  /// is active.
  final String? searchHint;

  /// Localized "no results" copy for the checklist's search box.
  final String? noResultsLabel;

  final FacetPresentation presentation;
  final int searchThreshold;

  /// Optional per-value icon, shown in the chips presentation only (e.g.
  /// a category icon next to its label).
  final IconData? Function(String valueId)? iconOf;
}
