import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/domain/trip.dart';
import '../domain/place.dart';
import 'add_place_screen.dart';
import 'place_actions_sheet.dart';
import 'place_providers.dart';
import 'place_visit_actions.dart';
import 'place_widgets.dart';

/// Places tab inside a trip's detail screen (fills the M1 shell).
class TripPlacesTab extends ConsumerStatefulWidget {
  const TripPlacesTab({super.key, required this.trip});

  final Trip trip;

  @override
  ConsumerState<TripPlacesTab> createState() => _TripPlacesTabState();
}

class _TripPlacesTabState extends ConsumerState<TripPlacesTab> {
  Set<PlaceCategory> _categoryFilter = {};
  Set<String> _countryFilter = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncPlaces = ref.watch(tripPlacesProvider(widget.trip.id));
    final places = asyncPlaces.valueOrNull ?? const <Place>[];

    if (asyncPlaces.hasValue && places.isEmpty) {
      return EmptyState(
        icon: Icons.place_outlined,
        title: l10n.tripPlacesEmptyTitle,
        body: l10n.tripPlacesEmptyBody,
        ctaLabel: l10n.placesEmptyCta,
        onCta: () => AddPlaceScreen.open(context, tripId: widget.trip.id),
      );
    }

    final filtered = filterPlaces(
      places,
      categories: _categoryFilter,
      countries: _countryFilter,
    );
    final sorted = sortForList(filtered);
    final visitedCount = places.where((p) => p.isVisited).length;

    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
          child: SectionLabel(
            l10n.tripPlacesProgress(visitedCount, places.length),
          ),
        ),
        PlaceFilterBar(
          places: places,
          selectedCategories: _categoryFilter,
          selectedCountries: _countryFilter,
          onCategoriesChanged: (v) => setState(() => _categoryFilter = v),
          onCountriesChanged: (v) => setState(() => _countryFilter = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final place in sorted)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: PlaceRowCard(
              place: place,
              onTap: () => showPlaceActionsSheet(context, ref, place),
              onToggleVisited: () =>
                  markPlaceVisited(ref, place, visited: !place.isVisited),
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: Text(l10n.placesEmptyCta),
          onPressed: () => AddPlaceScreen.open(context, tripId: widget.trip.id),
        ),
      ],
    );
  }
}
