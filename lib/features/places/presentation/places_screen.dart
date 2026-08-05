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

class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final asyncPlaces = ref.watch(placeListProvider);
    final places = asyncPlaces.valueOrNull ?? const <Place>[];
    final stats = ref.watch(placeStatsProvider);
    final trips = ref.watch(tripListProvider).valueOrNull ?? [];
    final tripNames = {for (final t in trips) t.id: t.name};
    final mapMode = ref.watch(placesMapModeProvider);

    final want = places.where((p) => !p.isVisited).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final been = sortForList(places).where((p) => p.isVisited).toList();

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
        places,
        want,
        been,
        stats,
        tripNames,
        mapMode,
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AsyncValue<List<Place>> asyncPlaces,
    List<Place> places,
    List<Place> want,
    List<Place> been,
    ({int countries, int visited, int days}) stats,
    Map<String, String> tripNames,
    bool mapMode,
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
    if (mapMode) {
      return PlacesMapView(
        places: places,
        focusPlaceId: ref.watch(selectedPlaceIdProvider),
        onFocusHandled: () =>
            ref.read(selectedPlaceIdProvider.notifier).state = null,
        onPlaceTap: (place) => showPlaceActionsSheet(context, ref, place),
      );
    }
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        PlaceStatsHeader(
          countries: stats.countries,
          visited: stats.visited,
          days: stats.days,
        ),
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

  Widget _row(
    BuildContext context,
    WidgetRef ref,
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
