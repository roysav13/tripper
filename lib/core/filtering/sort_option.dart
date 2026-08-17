import 'package:flutter/foundation.dart';

import 'sort_spec.dart';

/// Binds one sort field to a comparator and its human-facing labels.
///
/// [compare] is always the *ascending* comparator — the engine negates it
/// for [SortDirection.descending] itself, so implementers never write a
/// direction-aware comparator by hand.
@immutable
class SortOption<T, F extends Enum> {
  const SortOption({
    required this.field,
    required this.label,
    required this.compare,
    required this.ascendingLabel,
    required this.descendingLabel,
    this.defaultDirection = SortDirection.ascending,
    this.hasValue,
    this.tiebreak,
    this.directional = true,
  });

  final F field;

  /// Localized field name shown in the sort picker, e.g. "Date visited".
  final String label;

  /// Ascending comparator. Only ever called on items for which [hasValue]
  /// (or an absent [hasValue]) is true.
  final Comparator<T> compare;

  /// Localized label for the ascending direction, e.g. "Oldest first".
  final String ascendingLabel;

  /// Localized label for the descending direction, e.g. "Newest first".
  final String descendingLabel;

  final SortDirection defaultDirection;

  /// Null means every item has a value. When provided, items for which
  /// this returns false always sort after every item with a value,
  /// regardless of direction.
  final bool Function(T item)? hasValue;

  /// A direction-independent secondary comparator, applied when [compare]
  /// (possibly negated by direction) returns 0. Never negated by
  /// direction itself.
  final Comparator<T>? tiebreak;

  /// False for a non-reversible default like "Recommended" — the sort
  /// picker renders no direction arrow and [SortSpec.direction] is
  /// ignored.
  final bool directional;
}

/// Applies [spec] to [items] using whichever option in [options] matches
/// its field (falling back to the first option if none match, rather than
/// throwing — e.g. a field that becomes unavailable after a permission is
/// revoked).
///
/// Three guarantees, all load-bearing:
/// - items without a value (per [SortOption.hasValue]) sort last, in both
///   directions;
/// - the sort is stable — equal keys keep their original input order, in
///   both directions, even though `List.sort` in Dart is not stable;
/// - [SortOption.tiebreak] is never negated by direction.
List<T> applySort<T, F extends Enum>(
  List<T> items,
  SortSpec<F> spec,
  List<SortOption<T, F>> options,
) {
  if (options.isEmpty) return items;
  SortOption<T, F>? matched;
  for (final option in options) {
    if (option.field == spec.field) {
      matched = option;
      break;
    }
  }
  final option = matched ?? options.first;
  final hasValue = option.hasValue;

  final indexed = <MapEntry<int, T>>[
    for (var i = 0; i < items.length; i++) MapEntry(i, items[i]),
  ];

  final withValue = <MapEntry<int, T>>[];
  final withoutValue = <MapEntry<int, T>>[];
  for (final entry in indexed) {
    if (hasValue == null || hasValue(entry.value)) {
      withValue.add(entry);
    } else {
      withoutValue.add(entry);
    }
  }

  final negate =
      option.directional && spec.direction == SortDirection.descending;

  int compareEntries(MapEntry<int, T> a, MapEntry<int, T> b) {
    var result = option.compare(a.value, b.value);
    if (negate) result = -result;
    if (result != 0) return result;

    final tiebreak = option.tiebreak;
    if (tiebreak != null) {
      final tieResult = tiebreak(a.value, b.value);
      if (tieResult != 0) return tieResult;
    }

    // Stability: true ties always keep original input order.
    return a.key.compareTo(b.key);
  }

  withValue.sort(compareEntries);

  return [
    for (final entry in withValue) entry.value,
    for (final entry in withoutValue) entry.value,
  ];
}
