import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/filtering/filter_engine.dart';
import '../../../core/filtering/filter_sort_config.dart';
import '../../../core/filtering/filter_sort_controller.dart';
import '../../../core/location/location_providers.dart';
import '../../../core/location/location_service.dart';
import '../../../core/settings/settings_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/filtering/active_filter_strip.dart';
import '../../../core/widgets/filtering/filter_sheet.dart';
import '../../../core/widgets/filtering/filter_sort_button.dart';
import '../../../core/widgets/filtering/filter_sort_view.dart';
import '../../../core/widgets/filtering/sort_sheet.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/domain/trip.dart';
import '../domain/place.dart';
import '../domain/place_collection.dart';
import '../domain/place_sort.dart';
import 'add_place_screen.dart';
import 'nearby_anchor_sheet.dart';
import 'place_actions_sheet.dart';
import 'place_collection_providers.dart';
import 'place_collections_row.dart';
import 'place_distance_sort_status.dart';
import 'place_filter_config.dart';
import 'place_providers.dart';
import 'place_visit_actions.dart';
import 'place_widgets.dart';
import 'places_map_view.dart';

/// Places tab inside a trip's detail screen (fills the M1 shell).
class TripPlacesTab extends ConsumerWidget {
  const TripPlacesTab({super.key, required this.trip, this.renderMap = true});

  final Trip trip;

  /// False in widget tests: Google Maps needs a platform view, same seam
  /// as `PlacesMapView`'s own `renderMap` and `TripJournalTab`'s.
  final bool renderMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // See PlacesScreen — same proactive fetch, same graceful-degradation
    // shape.
    final fix = ref.watch(currentLocationProvider).valueOrNull;
    final currentLocation =
        fix is LocationAvailable ? (lat: fix.lat, lng: fix.lng) : null;
    final collections = ref.watch(placeCollectionsProvider).valueOrNull ??
        const <PlaceCollection>[];
    final membershipsByPlace =
        ref.watch(placeCollectionMembershipsProvider).valueOrNull ?? const {};
    final config = buildPlaceFilterSortConfig(
      l10n,
      currentLocation: currentLocation,
      placeCollectionIds: membershipsByPlace,
      collectionNames: {for (final c in collections) c.id: c.name},
    );
    final scope = 'trip:${trip.id}';
    final itemsProvider = tripPlacesProvider(trip.id);

    return FilterSortView<Place, PlaceSortField>(
      itemsProvider: itemsProvider,
      controllerFamily: placeFilterSortProvider,
      scope: scope,
      config: config,
      builder: (context, all, visible, state) => _TripPlacesTabBody(
        trip: trip,
        all: all,
        visible: visible,
        sortState: state,
        config: config,
        scope: scope,
        itemsProvider: itemsProvider,
        currentLocation: currentLocation,
        collections: collections,
        renderMap: renderMap,
      ),
    );
  }
}

class _TripPlacesTabBody extends ConsumerWidget {
  const _TripPlacesTabBody({
    required this.trip,
    required this.all,
    required this.visible,
    required this.sortState,
    required this.config,
    required this.scope,
    required this.itemsProvider,
    required this.currentLocation,
    required this.collections,
    required this.renderMap,
  });

  final Trip trip;
  final List<Place> all;
  final List<Place> visible;
  final FilterSortState<PlaceSortField> sortState;
  final FilterSortConfig<Place, PlaceSortField> config;
  final String scope;
  final ProviderListenable<AsyncValue<List<Place>>> itemsProvider;
  final ({double lat, double lng})? currentLocation;
  final List<PlaceCollection> collections;
  final bool renderMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final asyncPlaces = ref.watch(itemsProvider);
    final nearbyEnabled = ref.watch(nearbyPlacesEnabledProvider);
    final mapMode = ref.watch(tripPlacesMapModeProvider(trip.id));

    if (asyncPlaces.hasError) {
      return ErrorState(
        onRetry: () => ref.invalidate(tripPlacesProvider(trip.id)),
      );
    }
    if (asyncPlaces.hasValue && all.isEmpty) {
      return EmptyState(
        icon: Icons.place_outlined,
        title: l10n.tripPlacesEmptyTitle,
        body: l10n.tripPlacesEmptyBody,
        ctaLabel: l10n.placesEmptyCta,
        onCta: () => AddPlaceScreen.open(context, tripId: trip.id),
      );
    }

    final visitedCount = all.where((p) => p.isVisited).length;

    final header = Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: SectionLabel(
              l10n.tripPlacesProgress(visitedCount, all.length),
            ),
          ),
          IconButton(
            icon: Icon(
              mapMode ? Icons.view_list_outlined : Icons.map_outlined,
            ),
            tooltip: mapMode ? l10n.listViewToggle : l10n.mapViewToggle,
            onPressed: () => ref
                .read(tripPlacesMapModeProvider(trip.id).notifier)
                .state = !mapMode,
          ),
          if (nearbyEnabled)
            IconButton(
              icon: const Icon(Icons.travel_explore),
              tooltip: l10n.nearbyEntryTooltip,
              onPressed: () => showNearbyAnchorSheet(
                context,
                ref,
                places: all,
                tripId: trip.id,
              ),
            ),
        ],
      ),
    );

    final filterSortRow = Row(
      children: [
        FilterButton(
          active: !sortState.selection.isEmpty,
          onPressed: () => showFilterSheet<Place, PlaceSortField>(
            context,
            itemsProvider: itemsProvider,
            controllerFamily: placeFilterSortProvider,
            scope: scope,
            config: config,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SortButton(
          onPressed: () => showSortSheet<Place, PlaceSortField>(
            context,
            controllerFamily: placeFilterSortProvider,
            scope: scope,
            config: config,
            sortSubtitleBuilder: (context, ref, field) =>
                field == PlaceSortField.distance
                    ? const PlaceDistanceSortStatus()
                    : null,
          ),
        ),
      ],
    );

    if (mapMode) {
      // Same filtering + lists options as list mode above — the map is
      // just a different rendering of `visible`, not a separate surface
      // with its own state.
      return Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.lg,
              end: AppSpacing.lg,
              top: AppSpacing.lg,
            ),
            child: header,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
            ),
            child: filterSortRow,
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
            ),
            child: PlaceCollectionsRow(collections: collections),
          ),
          if (!sortState.selection.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: _activeFilterStrip(ref),
            ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: PlacesMapView(
              places: visible,
              renderMap: renderMap,
              onPlaceTap: (place) => showPlaceActionsSheet(context, ref, place),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        header,
        filterSortRow,
        const SizedBox(height: AppSpacing.sm),
        PlaceCollectionsRow(collections: collections),
        const SizedBox(height: AppSpacing.sm),
        if (!sortState.selection.isEmpty) _activeFilterStrip(ref),
        const SizedBox(height: AppSpacing.sm),
        for (final place in visible)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: RowSettleAnimation(
              placeId: place.id,
              child: PlaceRowCard(
                place: place,
                dayNumber: _dayNumberFor(place),
                distanceKm: currentLocation != null && place.hasLocation
                    ? placeDistanceFromKm(
                        place,
                        lat: currentLocation!.lat,
                        lng: currentLocation!.lng,
                      )
                    : null,
                onTap: () => showPlaceActionsSheet(context, ref, place),
                onToggleVisited: () {
                  HapticFeedback.selectionClick();
                  markPlaceVisited(ref, place, visited: !place.isVisited);
                },
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: Text(l10n.placesEmptyCta),
          onPressed: () => AddPlaceScreen.open(context, tripId: trip.id),
        ),
      ],
    );
  }

  int? _dayNumberFor(Place place) =>
      (trip.startDate != null && place.plannedDate != null)
          ? trip.dayNumber(place.plannedDate!)
          : null;

  Widget _activeFilterStrip(WidgetRef ref) {
    final active = <ActiveFilterEntry>[];
    for (final facet in config.facets) {
      final available = availableFacetValues(all, facet);
      for (final valueId in sortState.selection.valuesFor(facet.id)) {
        for (final value in available) {
          if (value.id == valueId) {
            active.add(ActiveFilterEntry(facetId: facet.id, value: value));
            break;
          }
        }
      }
    }
    final notifier = ref.read(placeFilterSortProvider(scope).notifier);
    return ActiveFilterStrip(
      active: active,
      onRemove: notifier.removeValue,
      onClearAll: notifier.clearFilters,
    );
  }
}
