import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/filtering/filter_selection.dart';

void main() {
  group('FilterSelection', () {
    test('empty selection has no active values', () {
      expect(FilterSelection.empty.isEmpty, isTrue);
      expect(FilterSelection.empty.activeCount, 0);
    });

    test('toggle adds a value then removes it on a second toggle', () {
      final withValue = FilterSelection.empty.toggle('category', 'hotel');
      expect(withValue.valuesFor('category'), {'hotel'});
      expect(withValue.isEmpty, isFalse);

      final removed = withValue.toggle('category', 'hotel');
      expect(removed.valuesFor('category'), isEmpty);
      expect(removed.isEmpty, isTrue);
    });

    test('a facet key is never left present with an empty set', () {
      final withValue = FilterSelection.empty.toggle('category', 'hotel');
      final removed = withValue.remove('category', 'hotel');
      expect(removed.byFacet.containsKey('category'), isFalse);
      expect(removed, FilterSelection.empty);
    });

    test('removing a value not present is a no-op', () {
      final selection = FilterSelection.empty.toggle('category', 'hotel');
      expect(selection.remove('category', 'restaurant'), selection);
    });

    test('withValues with an empty set clears the facet', () {
      final selection = FilterSelection.empty.toggle('category', 'hotel');
      expect(
        selection.withValues('category', {}).byFacet.containsKey('category'),
        isFalse,
      );
    });

    test('clearFacet only clears the named facet', () {
      final selection = FilterSelection.empty
          .toggle('category', 'hotel')
          .toggle('country', 'Japan');
      final cleared = selection.clearFacet('category');
      expect(cleared.valuesFor('category'), isEmpty);
      expect(cleared.valuesFor('country'), {'Japan'});
    });

    test('activeCount sums values across all facets', () {
      final selection = FilterSelection.empty
          .toggle('category', 'hotel')
          .toggle('category', 'restaurant')
          .toggle('country', 'Japan');
      expect(selection.activeCount, 3);
    });

    test('two independently built equal selections compare equal', () {
      final a = FilterSelection.empty
          .toggle('category', 'hotel')
          .toggle('country', 'Japan');
      final b = FilterSelection.empty
          .toggle('country', 'Japan')
          .toggle('category', 'hotel');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('selections with different values are not equal', () {
      final a = FilterSelection.empty.toggle('category', 'hotel');
      final b = FilterSelection.empty.toggle('category', 'restaurant');
      expect(a, isNot(b));
    });
  });
}
