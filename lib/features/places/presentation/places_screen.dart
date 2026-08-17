import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/filtering/filter_engine.dart';
import '../../../core/filtering/filter_sort_config.dart';
import '../../../core/filtering/filter_sort_controller.dart';
import '../../../core/location/location_providers.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/filtering/active_filter_strip.dart';
import '../../../core/widgets/filtering/filter_sort_button.dart';
import '../../../core/widgets/filtering/filter_sort_sheet.dart';
import '../../../core/widgets/filtering/filter_sort_view.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/presentation/trip_providers.dart';
import '../domain/place.dart';
import '../domain/place_sort.dart';
import 'add_place_screen.dart';
import 'place_actions_sheet.dart';
import 'place_distance_sort_status.dart';
import 'place_filter_config.dart';
import 'place_providers.dart';
import 'place_visit_actions.dart';
import 'place_widgets.dart';
import 'places_map_view.dart';

const _scope = 'places';

class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Fetched proactively as soon as this screen opens (not gated behind
    // tapping "Distance") so the sort feels instant once picked; degrades
    // to `null` — every place valueless for that option, list keeps its
    // prior order — while pending, denied, or failed.
    final fix = ref.watch(currentLocationProvider).valueOrNull;
    final currentLocation =
        fix is LocationAvailable ? (lat: fix.lat, lng: fix.lng) : null;
    final config = buildPlaceFilterSortConfig(
      l10n,
      currentLocation: currentLocation,
    );

    return FilterSortView<Place, PlaceSortField>(
      itemsProvider: placeListProvider,
      controllerFamily: placeFilterSortProvider,
      scope: _scope,
      config: config,
      builder: (context, all, visible, state) => _PlacesScreenBody(
        all: all,
        visible: visible,
        sortState: state,
        config: config,
        currentLocation: currentLocation,
      ),
    );
  }
}

class _PlacesScreenBody extends ConsumerWidget {
  const _PlacesScreenBody({
    required this.all,
    required this.visible,
    required this.sortState,
    required this.config,
    required this.currentLocation,
  });

  final List<Place> all;
  final List<Place> visible;
  final FilterSortState<PlaceSortField> sortState;
  final FilterSortConfig<Place, PlaceSortField> config;
  final ({double lat, double lng})? currentLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final asyncPlaces = ref.watch(placeListProvider);
    final trips = ref.watch(tripListProvider).valueOrNull ?? [];
    final tripNames = {for (final t in trips) t.id: t.name};
    final mapMode = ref.watch(placesMapModeProvider);

    final want = visible.where((p) => !p.isVisited).toList();
    final been = visible.where((p) => p.isVisited).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabPlaces),
        actions: [
          if (all.isNotEmpty)
            IconButton(
              icon: Icon(
                mapMode ? Icons.view_list_outlined : Icons.map_outlined,
                color: colors.inkSecondary,
              ),
              tooltip: mapMode ? l10n.listViewToggle : l10n.mapViewToggle,
              onPressed: () =>
                  ref.read(placesMapModeProvider.notifier).state = !mapMode,
            ),
          if (all.isNotEmpty)
            FilterSortButton(
              active: !sortState.selection.isEmpty,
              onPressed: () => showFilterSortSheet<Place, PlaceSortField>(
                context,
                itemsProvider: placeListProvider,
                controllerFamily: placeFilterSortProvider,
                scope: _scope,
                config: config,
                sortSubtitleBuilder: (context, ref, field) =>
                    field == PlaceSortField.distance
                        ? const PlaceDistanceSortStatus()
                        : null,
              ),
            ),
          IconButton(
            icon: Icon(Icons.add, color: colors.accent),
            tooltip: l10n.placesEmptyCta,
            onPressed: () => AddPlaceScreen.open(context),
          ),
        ],
      ),
      body: _body(
        context,
        ref,
        l10n,
        asyncPlaces,
        tripNames,
        mapMode,
        want,
        been,
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AsyncValue<List<Place>> asyncPlaces,
    Map<String, String> tripNames,
    bool mapMode,
    List<Place> want,
    List<Place> been,
  ) {
    if (asyncPlaces.hasError) {
      return ErrorState(onRetry: () => ref.invalidate(placeListProvider));
    }
    if (asyncPlaces.hasValue && all.isEmpty) {
      return EmptyState(
        icon: Icons.place_outlined,
        title: l10n.placesEmptyTitle,
        body: l10n.placesEmptyBody,
        ctaLabel: l10n.placesEmptyCta,
        onCta: () => AddPlaceScreen.open(context),
      );
    }
    if (asyncPlaces.hasValue && all.isNotEmpty && visible.isEmpty) {
      return EmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: l10n.placesFilterEmptyTitle,
        body: l10n.placesFilterEmptyBody,
        ctaLabel: l10n.placesFilterEmptyCta,
        onCta: () =>
            ref.read(placeFilterSortProvider(_scope).notifier).clearFilters(),
      );
    }
    if (mapMode) {
      return Column(
        children: [
          if (!sortState.selection.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: _activeFilterStrip(ref),
            ),
          Expanded(
            child: PlacesMapView(
              places: visible,
              focusPlaceId: ref.watch(selectedPlaceIdProvider),
              onFocusHandled: () =>
                  ref.read(selectedPlaceIdProvider.notifier).state = null,
              onPlaceTap: (place) => showPlaceActionsSheet(context, ref, place),
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        if (!sortState.selection.isEmpty) ...[
          _activeFilterStrip(ref),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (want.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: SectionLabel(
              '${l10n.placesWantSection} · ${want.length}',
              accent: true,
            ),
          ),
          for (final place in want) _row(context, ref, place, tripNames),
        ],
        if (been.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: SectionLabel(
              '${l10n.placesBeenSection} · ${been.length}',
            ),
          ),
          for (final place in been) _row(context, ref, place, tripNames),
        ],
      ],
    );
  }

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
    final notifier = ref.read(placeFilterSortProvider(_scope).notifier);
    return ActiveFilterStrip(
      active: active,
      onRemove: notifier.removeValue,
      onClearAll: notifier.clearFilters,
    );
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    Place place,
    Map<String, String> tripNames,
  ) {
    final loc = currentLocation;
    final distanceKm = loc != null && place.hasLocation
        ? placeDistanceFromKm(place, lat: loc.lat, lng: loc.lng)
        : null;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: RowSettleAnimation(
        placeId: place.id,
        child: PlaceRowCard(
          place: place,
          tripName: place.tripId == null ? null : tripNames[place.tripId],
          distanceKm: distanceKm,
          onTap: () => showPlaceActionsSheet(context, ref, place),
          onToggleVisited: () {
            HapticFeedback.selectionClick();
            markPlaceVisited(ref, place, visited: !place.isVisited);
          },
        ),
      ),
    );
  }
}
