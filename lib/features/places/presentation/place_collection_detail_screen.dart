import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/place.dart';
import '../domain/place_collection.dart';
import 'list_name_dialog.dart';
import 'place_actions_sheet.dart';
import 'place_collection_providers.dart';
import 'place_providers.dart';
import 'place_visit_actions.dart';
import 'place_widgets.dart';

enum _ListAction { rename, delete }

/// All the places in one user-made list — "showing them together" (the
/// feature's whole point) via the same [PlaceRowCard] the Places tab uses.
class PlaceCollectionDetailScreen extends ConsumerWidget {
  const PlaceCollectionDetailScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final collections = ref.watch(placeCollectionsProvider).valueOrNull;
    final collection =
        collections?.where((c) => c.id == collectionId).firstOrNull;

    if (collections == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    if (collection == null) {
      // Deleted (from this screen's own menu, or elsewhere) while open.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final allPlaces = ref.watch(placeListProvider).valueOrNull ?? const [];
    final memberships =
        ref.watch(placeCollectionMembershipsProvider).valueOrNull ?? const {};
    final places = allPlaces
        .where((p) => memberships[p.id]?.contains(collectionId) ?? false)
        .toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    return Scaffold(
      appBar: AppBar(
        title: Text(collection.name),
        actions: [
          PopupMenuButton<_ListAction>(
            onSelected: (action) {
              switch (action) {
                case _ListAction.rename:
                  _rename(context, ref, collection);
                case _ListAction.delete:
                  _delete(context, ref, collection);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _ListAction.rename,
                child: Text(l10n.renameListMenuItem),
              ),
              PopupMenuItem(
                value: _ListAction.delete,
                child: Text(l10n.deleteListMenuItem),
              ),
            ],
          ),
        ],
      ),
      body: places.isEmpty
          ? EmptyState(
              icon: Icons.list_alt_outlined,
              title: l10n.listDetailEmptyTitle,
              body: l10n.listDetailEmptyBody,
              ctaLabel: l10n.listDetailEmptyCta,
              onCta: () => Navigator.of(context).pop(),
            )
          : ListView.separated(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              itemCount: places.length,
              separatorBuilder: (context, i) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _row(context, ref, places[i]),
            ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, Place place) {
    return PlaceRowCard(
      place: place,
      onTap: () => showPlaceActionsSheet(context, ref, place),
      onToggleVisited: () =>
          markPlaceVisited(ref, place, visited: !place.isVisited),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    PlaceCollection collection,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await promptListName(
      context,
      title: l10n.renameListDialogTitle,
      confirmLabel: l10n.save,
      initial: collection.name,
    );
    if (name == null) return;
    await ref
        .read(placeCollectionRepositoryProvider)
        .renameCollection(collection.id, name: name);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PlaceCollection collection,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteListTitle),
        content: Text(l10n.deleteListBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.menuDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref
          .read(placeCollectionRepositoryProvider)
          .deleteCollection(collection.id);
    }
  }
}
