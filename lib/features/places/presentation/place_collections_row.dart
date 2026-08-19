import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/place_collection.dart';
import 'list_name_dialog.dart';
import 'place_collection_detail_screen.dart';
import 'place_collection_providers.dart';

/// Horizontal row of the user's lists ("Tokyo day trips", "Food") above the
/// Places sections — the discovery surface for the feature: always visible
/// (even with zero lists yet, via the trailing "New list" chip) so grouping
/// places is something a user stumbles into rather than has to go hunting
/// for in a menu.
class PlaceCollectionsRow extends ConsumerWidget {
  const PlaceCollectionsRow({super.key, required this.collections});

  final List<PlaceCollection> collections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: collections.length + 1,
        separatorBuilder: (context, i) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          if (i == collections.length) {
            return ActionChip(
              avatar: Icon(Icons.add, size: 16, color: colors.accent),
              label: Text(l10n.newListChipLabel),
              onPressed: () => _createList(context, ref),
            );
          }
          final collection = collections[i];
          return ActionChip(
            label: Text(collection.name),
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (context) =>
                    PlaceCollectionDetailScreen(collectionId: collection.id),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createList(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await promptListName(
      context,
      title: l10n.newListDialogTitle,
      confirmLabel: l10n.newListDialogCreate,
    );
    if (name == null) return;
    await ref.read(placeCollectionRepositoryProvider).createCollection(
          name: name,
        );
  }
}
