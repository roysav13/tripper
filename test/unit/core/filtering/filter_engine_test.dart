import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/filtering/facet.dart';
import 'package:tripper/core/filtering/filter_engine.dart';
import 'package:tripper/core/filtering/filter_selection.dart';

class _Item {
  const _Item(this.id, {this.categories = const {}, this.country});
  final String id;
  final Set<String> categories;
  final String? country;
}

Facet<_Item> _categoryFacet() => Facet<_Item>(
      id: 'category',
      label: 'Category',
      valuesOf: (item) => {
        for (final c in item.categories) FacetValue(id: c, label: c),
      },
    );

Facet<_Item> _countryFacet() => Facet<_Item>(
      id: 'country',
      label: 'Country',
      valuesOf: (item) => item.country == null
          ? {}
          : {FacetValue(id: item.country!, label: item.country!)},
    );

void main() {
  final items = [
    const _Item('a', categories: {'hotel'}, country: 'Thailand'),
    const _Item('b', categories: {'restaurant'}, country: 'Thailand'),
    const _Item('c', categories: {'hotel'}, country: 'Japan'),
    const _Item('d', country: 'Japan'), // no category
    const _Item('e', categories: {'food', 'tokyo'}), // multi-valued facet
  ];
  final facets = [_categoryFacet(), _countryFacet()];

  group('applyFilter', () {
    test('empty selection returns everything unfiltered', () {
      expect(applyFilter(items, facets, FilterSelection.empty), items);
    });

    test('OR within a facet', () {
      final selection = FilterSelection.empty
          .toggle('category', 'hotel')
          .toggle('category', 'restaurant');
      final result = applyFilter(items, facets, selection);
      expect(result.map((i) => i.id), ['a', 'b', 'c']);
    });

    test('AND across facets', () {
      final selection = FilterSelection.empty
          .toggle('category', 'hotel')
          .toggle('country', 'Japan');
      final result = applyFilter(items, facets, selection);
      expect(result.map((i) => i.id), ['c']);
    });

    test('an item with no value in a facet never matches a non-empty selection',
        () {
      final selection = FilterSelection.empty.toggle('category', 'hotel');
      final result = applyFilter(items, facets, selection);
      expect(result.any((i) => i.id == 'd'), isFalse);
    });

    test('a multi-valued facet matches on any overlap (list-membership case)',
        () {
      final selection = FilterSelection.empty.toggle('category', 'food');
      final result = applyFilter(items, facets, selection);
      expect(result.map((i) => i.id), ['e']);
    });
  });

  group('availableFacetValues', () {
    test('dedupes by id and orders by sortKey', () {
      final values = availableFacetValues(items, _categoryFacet());
      expect(values.map((v) => v.id), ['food', 'hotel', 'restaurant', 'tokyo']);
    });

    test('a facet with no values present in the items is empty', () {
      final noCategoryItems = [const _Item('x', country: 'Chile')];
      expect(availableFacetValues(noCategoryItems, _categoryFacet()), isEmpty);
    });
  });

  group('filterMatchCount', () {
    test('matches applyFilter length', () {
      final selection = FilterSelection.empty.toggle('country', 'Japan');
      expect(
        filterMatchCount(items, facets, selection),
        applyFilter(items, facets, selection).length,
      );
    });
  });

  group('pruneSelection', () {
    test('returns the identical instance when nothing is stale', () {
      final selection = FilterSelection.empty.toggle('category', 'hotel');
      final pruned = pruneSelection(items, facets, selection);
      expect(identical(pruned, selection), isTrue);
    });

    test('drops a stale value id no longer present in the data', () {
      final selection = FilterSelection.empty.toggle('category', 'ghost');
      final pruned = pruneSelection(items, facets, selection);
      expect(pruned.valuesFor('category'), isEmpty);
      expect(identical(pruned, selection), isFalse);
    });

    test('drops the facet key entirely once it empties', () {
      final selection = FilterSelection.empty.toggle('category', 'ghost');
      final pruned = pruneSelection(items, facets, selection);
      expect(pruned.byFacet.containsKey('category'), isFalse);
    });

    test('keeps still-valid values while dropping stale ones in the same facet',
        () {
      final selection = FilterSelection.empty
          .toggle('category', 'hotel')
          .toggle('category', 'ghost');
      final pruned = pruneSelection(items, facets, selection);
      expect(pruned.valuesFor('category'), {'hotel'});
    });
  });
}
