import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/filtering/sort_option.dart';
import 'package:tripper/core/filtering/sort_spec.dart';

enum _Field { name, score, recommended }

class _Item {
  const _Item(this.id, {this.score});
  final String id;
  final int? score;
}

void main() {
  final byScore = SortOption<_Item, _Field>(
    field: _Field.score,
    label: 'Score',
    hasValue: (i) => i.score != null,
    compare: (a, b) => a.score!.compareTo(b.score!),
    ascendingLabel: 'Lowest first',
    descendingLabel: 'Highest first',
  );

  final nonDirectional = SortOption<_Item, _Field>(
    field: _Field.recommended,
    label: 'Recommended',
    compare: (a, b) => 0,
    ascendingLabel: 'Recommended',
    descendingLabel: 'Recommended',
    directional: false,
  );

  group('applySort', () {
    test('missing-value items sort last, ascending', () {
      final items = [
        const _Item('no-score'),
        const _Item('two', score: 2),
        const _Item('one', score: 1),
      ];
      final result = applySort(
        items,
        const SortSpec(_Field.score, SortDirection.ascending),
        [byScore],
      );
      expect(result.map((i) => i.id), ['one', 'two', 'no-score']);
    });

    test('missing-value items sort last, descending too', () {
      final items = [
        const _Item('no-score'),
        const _Item('two', score: 2),
        const _Item('one', score: 1),
      ];
      final result = applySort(
        items,
        const SortSpec(_Field.score, SortDirection.descending),
        [byScore],
      );
      expect(result.map((i) => i.id), ['two', 'one', 'no-score']);
    });

    test('stable: equal keys preserve input order in both directions', () {
      final items = [
        const _Item('first', score: 5),
        const _Item('second', score: 5),
        const _Item('third', score: 5),
      ];
      final asc = applySort(
        items,
        const SortSpec(_Field.score, SortDirection.ascending),
        [byScore],
      );
      expect(asc.map((i) => i.id), ['first', 'second', 'third']);

      final desc = applySort(
        items,
        const SortSpec(_Field.score, SortDirection.descending),
        [byScore],
      );
      expect(desc.map((i) => i.id), ['first', 'second', 'third']);
    });

    test('flipping direction twice returns to the original order', () {
      final items = [
        const _Item('a', score: 3),
        const _Item('b', score: 1),
        const _Item('c', score: 3),
        const _Item('d', score: 2),
      ];
      final once = applySort(
        items,
        const SortSpec(_Field.score, SortDirection.ascending),
        [byScore],
      );
      final twice = applySort(
        once,
        const SortSpec(_Field.score, SortDirection.descending),
        [byScore],
      );
      final thrice = applySort(
        twice,
        const SortSpec(_Field.score, SortDirection.ascending),
        [byScore],
      );
      expect(thrice.map((i) => i.id), once.map((i) => i.id));
    });

    test('tiebreak is never negated by direction', () {
      final withTiebreak = SortOption<_Item, _Field>(
        field: _Field.score,
        label: 'Score',
        compare: (a, b) => 0, // everything ties on the primary key
        tiebreak: (a, b) => a.id.compareTo(b.id), // always ascending by id
        ascendingLabel: 'Asc',
        descendingLabel: 'Desc',
      );
      final items = [
        const _Item('c'),
        const _Item('a'),
        const _Item('b'),
      ];
      final asc = applySort(
        items,
        const SortSpec(_Field.score, SortDirection.ascending),
        [withTiebreak],
      );
      final desc = applySort(
        items,
        const SortSpec(_Field.score, SortDirection.descending),
        [withTiebreak],
      );
      expect(asc.map((i) => i.id), ['a', 'b', 'c']);
      expect(desc.map((i) => i.id), ['a', 'b', 'c']);
    });

    test('directional: false ignores direction entirely', () {
      final items = [const _Item('a'), const _Item('b')];
      final asc = applySort(
        items,
        const SortSpec(_Field.recommended, SortDirection.ascending),
        [nonDirectional],
      );
      final desc = applySort(
        items,
        const SortSpec(_Field.recommended, SortDirection.descending),
        [nonDirectional],
      );
      expect(asc.map((i) => i.id), desc.map((i) => i.id));
    });

    test(
        'a spec naming a field with no matching option falls back instead of throwing',
        () {
      final items = [const _Item('a', score: 2), const _Item('b', score: 1)];
      final result = applySort(
        items,
        const SortSpec(_Field.name, SortDirection.ascending),
        [byScore],
      );
      expect(result.map((i) => i.id), ['b', 'a']);
    });
  });

  group('SortSpec', () {
    test('flipped toggles direction and keeps field', () {
      const spec = SortSpec(_Field.score, SortDirection.ascending);
      final flipped = spec.flipped();
      expect(flipped.field, _Field.score);
      expect(flipped.direction, SortDirection.descending);
    });

    test('equality is by field and direction', () {
      const a = SortSpec(_Field.score, SortDirection.ascending);
      const b = SortSpec(_Field.score, SortDirection.ascending);
      const c = SortSpec(_Field.score, SortDirection.descending);
      expect(a, b);
      expect(a, isNot(c));
    });
  });
}
