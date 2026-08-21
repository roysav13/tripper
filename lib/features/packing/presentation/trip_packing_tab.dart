import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/domain/trip.dart';
import '../domain/packing_category.dart';
import '../domain/packing_item_status.dart';
import '../domain/trip_packing_item.dart';
import 'packing_providers.dart';
import 'packing_widgets.dart';

class TripPackingTab extends ConsumerStatefulWidget {
  const TripPackingTab({super.key, required this.trip});

  final Trip trip;

  @override
  ConsumerState<TripPackingTab> createState() => _TripPackingTabState();
}

class _TripPackingTabState extends ConsumerState<TripPackingTab> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncItems = ref.watch(tripPackingItemsProvider(widget.trip.id));

    // Everything below returns through this one Scaffold — Task 5 adds
    // `floatingActionButton:` and Task 6 adds `appBar:` to this same
    // widget rather than restructuring it, so the overflow menu (once
    // Task 6 adds it) is reachable from every state, including empty and
    // error, not just the populated list.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _body(context, l10n, asyncItems),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<List<TripPackingItem>> asyncItems,
  ) {
    if (asyncItems.hasError) {
      return ErrorState(
        onRetry: () => ref.invalidate(tripPackingItemsProvider(widget.trip.id)),
      );
    }

    final items = asyncItems.valueOrNull ?? const <TripPackingItem>[];

    if (asyncItems.hasValue && items.isEmpty) {
      return EmptyState(
        icon: Icons.luggage_outlined,
        title: l10n.packingEmptyTitle,
        body: l10n.packingEmptyBody,
        ctaLabel: l10n.packingEmptyCta,
        onCta: () {}, // Wired to the add-item sheet in Task 5.
      );
    }

    final byCategory = <PackingCategory, List<TripPackingItem>>{};
    for (final item in items) {
      (byCategory[item.category] ??= []).add(item);
    }

    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        for (final category in PackingCategory.values)
          if (byCategory[category] case final categoryItems?
              when categoryItems.isNotEmpty) ...[
            SectionLabel(packingCategoryLabel(l10n, category)),
            const SizedBox(height: AppSpacing.sm),
            for (final item in categoryItems) ...[
              _ItemRow(item: item),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.item});

  final TripPackingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isClothing = item.category == PackingCategory.clothing;

    return PaperCard(
      onTap: isClothing ? () => _pickStatus(context, ref) : null,
      child: Row(
        children: [
          if (!isClothing)
            Checkbox(
              value: item.status == PackingItemStatus.packed,
              onChanged: (checked) =>
                  ref.read(packingRepositoryProvider).updateTripItemStatus(
                        item.id,
                        (checked ?? false)
                            ? PackingItemStatus.packed
                            : PackingItemStatus.toPack,
                      ),
            ),
          Expanded(
            child: Text(item.label, overflow: TextOverflow.ellipsis),
          ),
          if (isClothing) PackingStatusChip(status: item.status),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStatus(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final status = await showModalBottomSheet<PackingItemStatus>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in PackingItemStatus.values)
              ListTile(
                title: Text(packingStatusLabel(l10n, s)),
                selected: s == item.status,
                onTap: () => Navigator.of(context).pop(s),
              ),
          ],
        ),
      ),
    );
    if (status == null) return;
    await ref
        .read(packingRepositoryProvider)
        .updateTripItemStatus(item.id, status);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePackingItemTitle),
        content: Text(l10n.deletePackingItemBody),
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
    if (confirmed != true || !context.mounted) return;
    final repo = ref.read(packingRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repo.deleteTripItem(item.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.packingItemDeleted)));
  }
}
