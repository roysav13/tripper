import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_providers.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/place.dart';
import 'nearby_places_screen.dart';

/// Entry point for Near By: pick an anchor (current position or a saved
/// place with a location), then push the results screen. [places] is the
/// current screen's place list, pre-scoped by the caller (all places for
/// PlacesScreen, just this trip's for TripPlacesTab) — filtered here to
/// ones with a location, since an anchor with no coordinates can't drive a
/// nearby search.
Future<void> showNearbyAnchorSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<Place> places,
  String? tripId,
}) {
  final located = places.where((p) => p.hasLocation).toList();
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    builder: (context) => _NearbyAnchorSheet(places: located, tripId: tripId),
  );
}

class _NearbyAnchorSheet extends ConsumerWidget {
  const _NearbyAnchorSheet({required this.places, required this.tripId});

  final List<Place> places;
  final String? tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final fix = ref.watch(currentLocationProvider).valueOrNull;
    final nearMeAvailable = fix is LocationAvailable;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            enabled: nearMeAvailable,
            leading: const Icon(Icons.my_location),
            title: Text(l10n.nearbyAnchorNearMe),
            subtitle: nearMeAvailable
                ? null
                : Text(l10n.nearbyAnchorNearMeUnavailable),
            onTap: !nearMeAvailable
                ? null
                : () {
                    final available = fix as LocationAvailable;
                    Navigator.of(context).pop();
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NearbyPlacesScreen(
                          anchorLat: available.lat,
                          anchorLng: available.lng,
                          tripId: tripId,
                        ),
                      ),
                    );
                  },
          ),
          ListTile(
            enabled: places.isNotEmpty,
            leading: const Icon(Icons.place_outlined),
            title: Text(l10n.nearbyAnchorSavedPlace),
            subtitle:
                places.isEmpty ? Text(l10n.nearbyAnchorNoSavedPlaces) : null,
            onTap: places.isEmpty
                ? null
                : () {
                    Navigator.of(context).pop();
                    _showPlacePicker(context);
                  },
          ),
        ],
      ),
    );
  }

  void _showPlacePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final place in places)
              Builder(
                builder: (context) {
                  final colors = context.colors;
                  final meta = [
                    if (place.city.isNotEmpty) place.city,
                    if (place.country.isNotEmpty) place.country,
                  ].join(' · ');
                  return ListTile(
                    leading: Icon(Icons.place_outlined, color: colors.accent),
                    title: Text(place.name),
                    subtitle: meta.isEmpty ? null : Text(meta),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute<void>(
                          builder: (_) => NearbyPlacesScreen(
                            anchorLat: place.lat!,
                            anchorLng: place.lng!,
                            tripId: tripId,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
