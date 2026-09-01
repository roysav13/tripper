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
import 'apply_template_sheet.dart';
import 'packing_item_form_sheet.dart';
import 'packing_providers.dart';
import 'packing_template_manager_screen.dart';
import 'packing_widgets.dart';

enum _PackingMenuAction { apply, manage }

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
    final hasItems = (asyncItems.valueOrNull ?? const []).isNotEmpty;

    // Everything below returns through this one Scaffold, with its own
    // transparent AppBar hosting the overflow menu — reachable from every
    // state, including empty and error, not just the populated list.
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // This tab sits inside TripDetailScreen's pushed route, which already
        // draws its own BackButton in its glass topbar. Without this, Flutter
        // synthesises a second one here and two back arrows stack up on this
        // one tab only.
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<_PackingMenuAction>(
            onSelected: (action) {
              switch (action) {
                case _PackingMenuAction.apply:
                  showApplyTemplateSheet(context, tripId: widget.trip.id);
                case _PackingMenuAction.manage:
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          const PackingTemplateManagerScreen(),
                    ),
                  );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _PackingMenuAction.apply,
                child: Text(l10n.packingApplyTemplateAction),
              ),
              PopupMenuItem(
                value: _PackingMenuAction.manage,
                child: Text(l10n.packingManageTemplatesAction),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: hasItems
          ? FloatingActionButton(
              onPressed: () =>
                  showPackingItemFormSheet(context, tripId: widget.trip.id),
              child: const Icon(Icons.add),
            )
          : null,
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
        onCta: () => showPackingItemFormSheet(context, tripId: widget.trip.id),
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
    final l10n = AppLocalizations.of(context)!;
    final isClothing = item.category == PackingCategory.clothing;

    return PaperCard(
      onTap: isClothing ? () => _pickStatus(context, ref) : null,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
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
          // No overflow/maxLines: a long label wraps onto a second line
          // instead of truncating with an ellipsis.
          Expanded(
            child: isClothing
                ? Text(item.label)
                : InkWell(
                    onTap: () => showPackingItemFormSheet(
                      context,
                      tripId: item.tripId,
                      existingId: item.id,
                      existingLabel: item.label,
                      existingCategory: item.category,
                    ),
                    child: Text(item.label),
                  ),
          ),
          if (isClothing) ...[
            PackingStatusChip(status: item.status),
            // A clothing row's whole-card tap is spoken for by the status
            // picker, so without this its label could never be edited —
            // only deleted and re-created.
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.menuEdit,
              onPressed: () => showPackingItemFormSheet(
                context,
                tripId: item.tripId,
                existingId: item.id,
                existingLabel: item.label,
                existingCategory: item.category,
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.menuDelete,
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
