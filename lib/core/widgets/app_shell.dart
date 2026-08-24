import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/places/data/geocoding_service.dart';
import '../../features/places/presentation/add_place_screen.dart';
import '../../features/places/presentation/place_candidate_review_screen.dart';
import '../../features/places/presentation/tiktok_cover_capture_screen.dart';
import '../../features/vault/presentation/document_form_sheet.dart';
import '../../l10n/app_localizations.dart';
import '../sharing/maps_link.dart';
import '../sharing/share_intent_service.dart';
import '../platform/storage_durability.dart';
import '../sharing/tiktok_link.dart';
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
      final text = share.texts.first;
      // A TikTok link routes into the video place-capture flow instead of
      // the Maps-link path below (design spec §5.1).
      if (parseTikTokShare(text) != null) {
        navigationShell.goBranch(2);
        final candidateName =
            await TikTokCoverCaptureScreen.open(context, sharedText: text);
        if (candidateName == null || !context.mounted) return;
        final candidate = await PlaceCandidateReviewScreen.open(
          context,
          candidateName: candidateName,
        );
        if (candidate == null || !context.mounted) return;
        await AddPlaceScreen.open(
          context,
          initialName: candidate.name,
          initialLat: candidate.lat,
          initialLng: candidate.lng,
          initialCountry: candidate.country,
          initialCity: candidate.city,
          initialSummary: candidate.summary,
        );
        return;
      }
      // Text share: a Google Maps link becomes a place (SPEC §3.1).
      final link =
          await ref.read(mapsLinkServiceProvider).expand(share.texts.first);
      if (link == null) return;
      // Fill in whatever the link didn't carry (city/country, or coords).
      final prefill = await enrichSharedPlace(
        geocoder: ref.read(geocoderProvider),
        name: link.name,
        lat: link.lat,
        lng: link.lng,
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
        initialNotes: prefill.lat == null ? link.url : '',
      );
    });
    return Scaffold(
      body: Column(
        children: [
          const _EphemeralStorageBanner(),
          Expanded(child: navigationShell),
        ],
      ),
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

/// Shown only when the platform told us writes won't survive a restart —
/// today that means a browser that refused persistent storage. Silence
/// here would mean a user typing up a week of journal entries and losing
/// them on close, so this is the one condition that earns permanent
/// screen space rather than a Settings line.
class _EphemeralStorageBanner extends StatelessWidget {
  const _EphemeralStorageBanner();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StorageDurability>(
      valueListenable: storageDurability,
      builder: (context, durability, _) {
        if (durability != StorageDurability.ephemeral) {
          return const SizedBox.shrink();
        }
        final colors = context.colors;
        final l10n = AppLocalizations.of(context)!;
        return Material(
          color: colors.warning,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: colors.paper,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.storageNotPersistentWarning,
                      style: TextStyle(fontSize: 12, color: colors.paper),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
