import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/places/data/geocoding_service.dart';
import '../../features/places/presentation/add_place_screen.dart';
import '../../features/places/presentation/maps_list_import_screen.dart';
import 'maps_link.dart';

/// Opens the right screen for a parsed Google Maps share — shared by the
/// share-intent listener (`app_shell.dart`) and the manual paste dialog
/// (`import_maps_list_dialog.dart`) so the place-vs-list routing decision
/// isn't duplicated between them.
Future<void> openMapsShareResult(
  BuildContext context,
  WidgetRef ref,
  MapsShareResult result,
) async {
  switch (result) {
    case MapsPlaceShare(:final link):
      final prefill = await enrichSharedPlace(
        geocoder: ref.read(geocoderProvider),
        name: link.name,
        lat: link.lat,
        lng: link.lng,
      );
      if (!context.mounted) return;
      await AddPlaceScreen.open(
        context,
        initialName: prefill.name,
        initialLat: prefill.lat,
        initialLng: prefill.lng,
        initialCountry: prefill.country,
        initialCity: prefill.city,
        initialNotes: prefill.lat == null ? link.url : '',
      );
    case MapsListShare(:final url, :final nameGuess):
      await MapsListImportScreen.open(context, url: url, nameGuess: nameGuess);
  }
}
