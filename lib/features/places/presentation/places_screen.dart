import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/presentation/trip_providers.dart';
import '../domain/place.dart';
import 'add_place_screen.dart';
import 'place_actions_sheet.dart';
import 'place_providers.dart';
import 'place_visit_actions.dart';
import 'place_widgets.dart';
import 'places_map_view.dart';

class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({super.key});

  @override
  ConsumerState<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends ConsumerState<PlacesScreen> {
  Set<PlaceCategory> _categoryFilter = {};
  Set<String> _countryFilter = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final asyncPlaces = ref.watch(placeListProvider);
    final places = asyncPlaces.valueOrNull ?? const <Place>[];

    // Cross-task issue (final review): a filter chip only renders for
    // categories/countries actually present in `places`. If the last place
    // matching an active filter is edited or deleted, its chip disappears
    // but the stale selection lingered in state forever (StatefulShellRoute
    // keeps this State alive across navigation) — stranding the list empty
    // with no visible way to recover. Prune the selection against what's
    // still present every build, and write the pruned result back so the
    // filter bar's displayed selection never outlives its chip.
    final availableCategories = {
      for (final p in places)
        if (p.category != null) p.category!,
    };
    final availableCountries = {
      for (final p in places)
        if (p.country.trim().isNotEmpty) p.country,
    };
    final prunedCategories = _categoryFilter.intersection(availableCategories);
    final prunedCountries = _countryFilter.intersection(availableCountries);
    if (prunedCategories.length != _categoryFilter.length ||
        prunedCountries.length != _countryFilter.length) {
      // Mutating state synchronously inside build() throws — defer to
      // after this frame completes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _categoryFilter = prunedCategories;
          _countryFilter = prunedCountries;
        });
      });
    }
    final filtered = filterPlaces(
      places,
      categories: prunedCategories,
      countries: prunedCountries,
    );
    final trips = ref.watch(tripListProvider).valueOrNull ?? [];
    final tripNames = {for (final t in trips) t.id: t.name};
    final mapMode = ref.watch(placesMapModeProvider);

    final want = filtered.where((p) => !p.isVisited).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final been = sortForList(filtered).where((p) => p.isVisited).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabPlaces),
        actions: [
          if (places.isNotEmpty)
            IconButton(
              icon: Icon(
                mapMode ? Icons.view_list_outlined : Icons.map_outlined,
                color: colors.inkSecondary,
              ),
              tooltip: mapMode ? l10n.listViewToggle : l10n.mapViewToggle,
              onPressed: () =>
                  ref.read(placesMapModeProvider.notifier).state = !mapMode,
            ),
          if (availableCategories.isNotEmpty || availableCountries.isNotEmpty)
            PlaceFilterButton(
              active:
                  prunedCategories.isNotEmpty || prunedCountries.isNotEmpty,
              onPressed: () => showPlaceFilterSheet(
                context,
                placesProvider: placeListProvider,
                selectedCategories: prunedCategories,
                selectedCountries: prunedCountries,
                onCategoriesChanged: (v) =>
                    setState(() => _categoryFilter = v),
                onCountriesChanged: (v) => setState(() => _countryFilter = v),
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
        l10n,
        asyncPlaces,
        places,
        filtered,
        want,
        been,
        tripNames,
        mapMode,
        prunedCategories,
        prunedCountries,
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<List<Place>> asyncPlaces,
    List<Place> places,
    List<Place> filtered,
    List<Place> want,
    List<Place> been,
    Map<String, String> tripNames,
    bool mapMode,
    Set<PlaceCategory> activeCategories,
    Set<String> activeCountries,
  ) {
    // M4.2 — states audit: same gap as trips/vault — a stream failure used
    // to fall straight through to an unexplained empty screen.
    if (asyncPlaces.hasError) {
      return ErrorState(onRetry: () => ref.invalidate(placeListProvider));
    }
    if (asyncPlaces.hasValue && places.isEmpty) {
      return EmptyState(
        icon: Icons.place_outlined,
        title: l10n.placesEmptyTitle,
        body: l10n.placesEmptyBody,
        ctaLabel: l10n.placesEmptyCta,
        onCta: () => AddPlaceScreen.open(context),
      );
    }
    // Fix 1 (final review): the filter sheet redesign removed the
    // always-visible inline chip row that used to occupy this space when a
    // filter combination matched nothing — without a branch here, a
    // zero-result filter fell through to a blank ListView with no
    // explanation and no way back.
    if (asyncPlaces.hasValue && places.isNotEmpty && filtered.isEmpty) {
      return EmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: l10n.placesFilterEmptyTitle,
        body: l10n.placesFilterEmptyBody,
        ctaLabel: l10n.placesFilterEmptyCta,
        onCta: () => setState(() {
          _categoryFilter = {};
          _countryFilter = {};
        }),
      );
    }
    if (mapMode) {
      return Column(
        children: [
          if (activeCategories.isNotEmpty || activeCountries.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: _activeFilterStrip(activeCategories, activeCountries),
            ),
          Expanded(
            child: PlacesMapView(
              places: filtered,
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
        if (activeCategories.isNotEmpty || activeCountries.isNotEmpty) ...[
          _activeFilterStrip(activeCategories, activeCountries),
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
          for (final place in want) _row(context, place, tripNames),
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
          for (final place in been) _row(context, place, tripNames),
        ],
      ],
    );
  }

  Widget _activeFilterStrip(
    Set<PlaceCategory> categories,
    Set<String> countries,
  ) {
    return ActiveFilterStrip(
      categories: categories,
      countries: countries,
      onRemoveCategory: (category) => setState(
        () => _categoryFilter = _categoryFilter.where((c) => c != category).toSet(),
      ),
      onRemoveCountry: (country) => setState(
        () => _countryFilter = _countryFilter.where((c) => c != country).toSet(),
      ),
      onClearAll: () => setState(() {
        _categoryFilter = {};
        _countryFilter = {};
      }),
    );
  }

  Widget _row(
    BuildContext context,
    Place place,
    Map<String, String> tripNames,
  ) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: RowSettleAnimation(
        placeId: place.id,
        child: PlaceRowCard(
          place: place,
          tripName: place.tripId == null ? null : tripNames[place.tripId],
          onTap: () => showPlaceActionsSheet(context, ref, place),
          onToggleVisited: () {
            // M4.4 — a quiet tick on the state change the whole tab is
            // built around; selectionClick (not a heavier impact) matches
            // the "classic, nothing springy" tone.
            HapticFeedback.selectionClick();
            markPlaceVisited(ref, place, visited: !place.isVisited);
          },
        ),
      ),
    );
  }
}
