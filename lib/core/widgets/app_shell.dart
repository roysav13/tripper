import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/places/data/geocoding_service.dart';
import '../../features/places/presentation/add_place_screen.dart';
import '../../features/vault/presentation/document_form_sheet.dart';
import '../../l10n/app_localizations.dart';
import '../sharing/maps_link.dart';
import '../sharing/share_intent_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Bottom-nav shell: Trips / Vault / Places (SPEC — 3 tabs, coral active).
/// Bar sits on the paper tone with a soft hairline — no hard edge.
/// Also hosts the share-target listener: a file shared into Tripper opens
/// the save-to-vault sheet from any screen.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    ref.listen(incomingSharesProvider, (previous, next) async {
      final share = next.valueOrNull;
      if (share == null || share.isEmpty) return;
      if (share.files.isNotEmpty) {
        navigationShell.goBranch(1);
        await showDocumentFormSheet(
          context,
          initialFilePath: share.files.first.path,
        );
        return;
      }
      // Text share: a Google Maps link becomes a place (SPEC §3.1).
      final result =
          await ref.read(mapsLinkServiceProvider).expand(share.texts.first);
      if (result == null) return;

      // For now, only handle place shares (list shares are handled in later tasks).
      final placeShare = result as MapsPlaceShare?;
      if (placeShare == null) return;

      // Fill in whatever the link didn't carry (city/country, or coords).
      final prefill = await enrichSharedPlace(
        geocoder: ref.read(geocoderProvider),
        name: placeShare.link.name,
        lat: placeShare.link.lat,
        lng: placeShare.link.lng,
      );
      if (!context.mounted) return;
      navigationShell.goBranch(2);
      await AddPlaceScreen.open(
        context,
        initialName: prefill.name,
        initialLat: prefill.lat,
        initialLng: prefill.lng,
        initialCountry: prefill.country,
        initialCity: prefill.city,
        initialNotes: prefill.lat == null ? placeShare.link.url : '',
      );
    });
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colors.hairline.withValues(alpha: 0.6),
              width: AppShape.hairlineWidth,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.luggage_outlined),
              label: l10n.tabTrips,
            ),
            NavigationDestination(
              icon: const Icon(Icons.folder_outlined),
              label: l10n.tabVault,
            ),
            NavigationDestination(
              icon: const Icon(Icons.place_outlined),
              label: l10n.tabPlaces,
            ),
          ],
        ),
      ),
    );
  }
}
