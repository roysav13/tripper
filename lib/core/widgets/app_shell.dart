import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/vault/presentation/document_form_sheet.dart';
import '../../l10n/app_localizations.dart';
import '../sharing/maps_link.dart';
import '../sharing/maps_share_routing.dart';
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
      // Text share: a Google Maps link becomes a place, or — for a shared
      // list — opens the bulk-import review screen (SPEC §3.1,
      // docs/superpowers/specs/2026-08-19-google-maps-list-share-design.md).
      final result =
          await ref.read(mapsLinkServiceProvider).expand(share.texts.first);
      if (result == null) return;
      if (!context.mounted) return;
      navigationShell.goBranch(2);
      await openMapsShareResult(context, ref, result);
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
