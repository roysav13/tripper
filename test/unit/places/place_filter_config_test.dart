import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/filtering/filter_engine.dart';
import 'package:tripper/core/filtering/filter_selection.dart';
import 'package:tripper/core/filtering/sort_option.dart';
import 'package:tripper/core/filtering/sort_spec.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/domain/place_sort.dart';
import 'package:tripper/features/places/presentation/place_filter_config.dart';
import 'package:tripper/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final config = buildPlaceFilterSortConfig(l10n);

  final places = [
    const Place(
      id: 'a',
      name: 'A',
      country: 'Thailand',
      category: PlaceCategory.hotel,
    ),
    const Place(
      id: 'b',
      name: 'B',
      country: 'Thailand',
      category: PlaceCategory.restaurant,
    ),
    const Place(
      id: 'c',
      name: 'C',
      country: 'Japan',
      category: PlaceCategory.hotel,
    ),
    const Place(id: 'd', name: 'D', country: 'Japan', category: null),
  ];

  group('facets, via applyFilter (ported filterPlaces cases)', () {
    test('no filters returns everything', () {
      expect(
        applyFilter(places, config.facets, FilterSelection.empty),
        hasLength(4),
      );
    });

    test('category facet is OR within the set', () {
      final selection = FilterSelection.empty
          .toggle('category', PlaceCategory.hotel.name)
          .toggle('category', PlaceCategory.restaurant.name);
      final result = applyFilter(places, config.facets, selection);
      expect(result.map((p) => p.id), ['a', 'b', 'c']);
    });

    test('country facet is OR within the set', () {
      final selection = FilterSelection.empty.toggle('country', 'Japan');
      final result = applyFilter(places, config.facets, selection);
      expect(result.map((p) => p.id), ['c', 'd']);
    });

    test('category and country facets combine with AND', () {
      final selection = FilterSelection.empty
          .toggle('category', PlaceCategory.hotel.name)
          .toggle('country', 'Japan');
      final result = applyFilter(places, config.facets, selection);
      expect(result.map((p) => p.id), ['c']);
    });

    test('an uncategorized place never matches an active category filter', () {
      final selection =
          FilterSelection.empty.toggle('category', PlaceCategory.hotel.name);
      final result = applyFilter(places, config.facets, selection);
      expect(result.any((p) => p.id == 'd'), isFalse);
    });
  });

  group('sort options', () {
    test('recommended reproduces the original mixed section ordering', () {
      final visitPlaces = [
        const Place(id: 'z', name: 'Zoo', status: PlaceStatus.beenThere),
        const Place(id: 'a', name: 'Aquarium'),
      ];
      final sorted = applySort(
        visitPlaces,
        const SortSpec(PlaceSortField.recommended, SortDirection.ascending),
        config.sortOptions,
      );
      expect(sorted.map((p) => p.id), ['a', 'z']);
    });

    test('name sort is alphabetical', () {
      final sorted = applySort(
        places,
        const SortSpec(PlaceSortField.name, SortDirection.ascending),
        config.sortOptions,
      );
      expect(sorted.map((p) => p.id), ['a', 'b', 'c', 'd']);
    });

    test(
        'distance sort is a no-op (all valueless, stable order) when no '
        'fix is available', () {
      final located = [
        const Place(id: 'x', name: 'X', lat: 1, lng: 1),
        const Place(id: 'y', name: 'Y', lat: 2, lng: 2),
      ];
      final sorted = applySort(
        located,
        const SortSpec(PlaceSortField.distance, SortDirection.ascending),
        config.sortOptions,
      );
      expect(sorted.map((p) => p.id), ['x', 'y']);
    });

    test(
        'distance sort orders by proximity to currentLocation and pushes '
        'places with no lat/lng last', () {
      final located = [
        const Place(id: 'far', name: 'Far', lat: 18.7883, lng: 98.9853),
        const Place(id: 'near', name: 'Near', lat: 14.3532, lng: 100.5686),
        const Place(id: 'no-location', name: 'No location'),
      ];
      final withFix = buildPlaceFilterSortConfig(
        l10n,
        currentLocation: (lat: 13.7563, lng: 100.5018),
      );
      final sorted = applySort(
        located,
        const SortSpec(PlaceSortField.distance, SortDirection.ascending),
        withFix.sortOptions,
      );
      expect(sorted.map((p) => p.id), ['near', 'far', 'no-location']);
    });

    test('visitedDate sort pushes places without a visit date last', () {
      final visitPlaces = [
        Place(
          id: 'no-date',
          name: 'No date',
          status: PlaceStatus.beenThere,
        ),
        Place(
          id: 'dated',
          name: 'Dated',
          status: PlaceStatus.beenThere,
          visitedAt: DateTime(2026, 1, 1),
        ),
      ];
      final sorted = applySort(
        visitPlaces,
        const SortSpec(
          PlaceSortField.visitedDate,
          SortDirection.ascending,
        ),
        config.sortOptions,
      );
      expect(sorted.map((p) => p.id), ['dated', 'no-date']);
    });
  });

  test('resultLabel matches the existing pluralized ARB string', () {
    expect(config.resultLabel(1), l10n.placesFilterShowResults(1));
    expect(config.resultLabel(3), l10n.placesFilterShowResults(3));
  });
}
