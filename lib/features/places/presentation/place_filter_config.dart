import '../../../core/filtering/facet.dart';
import '../../../core/filtering/filter_sort_config.dart';
import '../../../core/filtering/sort_option.dart';
import '../../../core/filtering/sort_spec.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/place.dart';
import '../domain/place_sort.dart';
import 'place_widgets.dart';

/// The Places feature's config for the generic filter+sort core: a
/// category facet (chips — 12 fixed values), a country facet (checklist —
/// unbounded, user-entered), and the recommended/name/visitedDate/distance
/// sort options.
///
/// [currentLocation] is the device's current GPS fix, if one is available
/// (null while it's still being fetched, permission was denied, or the
/// fix failed) — supplied fresh by the caller rather than read from
/// global state, same reasoning as [comparePlacesByDistance]'s [lat]/
/// [lng] parameters. When null, every place is valueless for the
/// Distance option (via `hasValue`) and the list keeps its prior order —
/// the graceful-degradation path required by CLAUDE.md hard rule 4.
///
/// [placeCollectionIds] (placeId -> the set of user-made list ids that
/// place belongs to) and [collectionNames] (list id -> current name) drive
/// the many-to-many "lists" facet — supplied fresh by the caller for the
/// same reason as [currentLocation] rather than read from global state
/// here.
FilterSortConfig<Place, PlaceSortField> buildPlaceFilterSortConfig(
  AppLocalizations l10n, {
  ({double lat, double lng})? currentLocation,
  Map<String, Set<String>> placeCollectionIds = const {},
  Map<String, String> collectionNames = const {},
}) {
  return FilterSortConfig<Place, PlaceSortField>(
    facets: [
      Facet<Place>(
        id: 'category',
        label: l10n.placesFilterCategorySection,
        presentation: FacetPresentation.chips,
        iconOf: (id) => placeCategoryIcon(PlaceCategory.values.byName(id)),
        valuesOf: (place) {
          final category = place.category;
          if (category == null) return const {};
          return {
            FacetValue(
              id: category.name,
              label: placeCategoryLabel(l10n, category),
              sortKey: category.index.toString().padLeft(3, '0'),
            ),
          };
        },
      ),
      Facet<Place>(
        id: 'country',
        label: l10n.placesFilterCountrySection,
        presentation: FacetPresentation.checklist,
        searchHint: l10n.placesFilterSearchCountry,
        noResultsLabel: l10n.placesFilterSearchNoResults,
        valuesOf: (place) {
          final country = place.country.trim();
          if (country.isEmpty) return const {};
          return {FacetValue(id: place.country, label: place.country)};
        },
      ),
      Facet<Place>(
        id: 'lists',
        label: l10n.placesFilterListsSection,
        presentation: FacetPresentation.checklist,
        searchHint: l10n.placesFilterSearchList,
        noResultsLabel: l10n.placesFilterSearchNoListsResults,
        valuesOf: (place) => {
          for (final id in placeCollectionIds[place.id] ?? const <String>{})
            if (collectionNames[id] case final name?)
              FacetValue(id: id, label: name),
        },
      ),
    ],
    sortOptions: [
      SortOption<Place, PlaceSortField>(
        field: PlaceSortField.recommended,
        label: l10n.placesSortRecommended,
        compare: comparePlacesRecommended,
        ascendingLabel: l10n.placesSortRecommended,
        descendingLabel: l10n.placesSortRecommended,
        directional: false,
      ),
      SortOption<Place, PlaceSortField>(
        field: PlaceSortField.name,
        label: l10n.placesSortName,
        compare: comparePlacesByName,
        ascendingLabel: l10n.sortAToZ,
        descendingLabel: l10n.sortZToA,
      ),
      SortOption<Place, PlaceSortField>(
        field: PlaceSortField.visitedDate,
        label: l10n.placesSortVisitedDate,
        hasValue: (place) => place.visitedAt != null,
        compare: comparePlacesByVisitedDate,
        ascendingLabel: l10n.sortOldestFirst,
        descendingLabel: l10n.sortNewestFirst,
        defaultDirection: SortDirection.descending,
      ),
      SortOption<Place, PlaceSortField>(
        field: PlaceSortField.distance,
        label: l10n.placesSortDistance,
        hasValue: (place) => place.hasLocation && currentLocation != null,
        compare: (a, b) => comparePlacesByDistance(
          a,
          b,
          lat: currentLocation?.lat ?? 0,
          lng: currentLocation?.lng ?? 0,
        ),
        ascendingLabel: l10n.sortNearestFirst,
        descendingLabel: l10n.sortFarthestFirst,
      ),
    ],
    defaultSort:
        const SortSpec(PlaceSortField.recommended, SortDirection.ascending),
    resultLabel: l10n.placesFilterShowResults,
  );
}
