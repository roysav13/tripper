import 'package:flutter/foundation.dart';

enum SortDirection {
  ascending,
  descending;

  SortDirection get flipped => this == SortDirection.ascending
      ? SortDirection.descending
      : SortDirection.ascending;
}

/// "The field being sorted by" + "the direction" — generic across every
/// feature that uses the filter/sort core. [F] is the feature's own sort
/// field enum, so a places screen can never accidentally be handed a
/// document sort spec.
@immutable
class SortSpec<F extends Enum> {
  const SortSpec(this.field, this.direction);

  final F field;
  final SortDirection direction;

  SortSpec<F> withField(F field) => SortSpec(field, direction);

  SortSpec<F> flipped() => SortSpec(field, direction.flipped);

  @override
  bool operator ==(Object other) =>
      other is SortSpec<F> &&
      other.field == field &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(field, direction);
}
