import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/packing_category.dart';
import '../domain/packing_template.dart';
import 'packing_item_form_sheet.dart';
import 'packing_providers.dart';
import 'packing_widgets.dart';

class PackingTemplateEditorScreen extends ConsumerWidget {
  const PackingTemplateEditorScreen({super.key, required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTemplates = ref.watch(packingTemplatesProvider);
    final template = (asyncTemplates.valueOrNull ?? const <PackingTemplate>[])
        .where((t) => t.id == templateId)
        .firstOrNull;
    final asyncItems = ref.watch(packingTemplateItemsProvider(templateId));

    return Scaffold(
      appBar: AppBar(title: Text(template?.name ?? '')),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            showPackingItemFormSheet(context, templateId: templateId),
        child: const Icon(Icons.add),
      ),
      body: _body(context, ref, asyncTemplates, asyncItems),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<PackingTemplate>> asyncTemplates,
    AsyncValue<List<PackingTemplateItem>> asyncItems,
  ) {
    final l10n = AppLocalizations.of(context)!;

    // Either stream failing means this screen can't be trusted — surface the
    // retry rather than a blank list that reads as "the template is empty".
    if (asyncItems.hasError || asyncTemplates.hasError) {
      return ErrorState(
        onRetry: () {
          ref.invalidate(packingTemplateItemsProvider(templateId));
          ref.invalidate(packingTemplatesProvider);
        },
      );
    }

    final items = asyncItems.valueOrNull ?? const <PackingTemplateItem>[];

    // "No items yet" is only knowable once the stream has actually emitted.
    if (asyncItems.hasValue && items.isEmpty) {
      return EmptyState(
        icon: Icons.checklist_outlined,
        title: l10n.packingEmptyTitle,
        body: l10n.packingEmptyBody,
        ctaLabel: l10n.packingEmptyCta,
        onCta: () => showPackingItemFormSheet(context, templateId: templateId),
      );
    }

    if (!asyncItems.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    return _list(context, ref, items);
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<PackingTemplateItem> items,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final byCategory = <PackingCategory, List<PackingTemplateItem>>{};
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
              PaperCard(
                onTap: () => showPackingItemFormSheet(
                  context,
                  templateId: templateId,
                  existingId: item.id,
                  existingTemplateItem: item,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(item.label)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: l10n.menuDelete,
                      onPressed: () => _deleteItem(context, ref, item),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }

  /// Same confirm-then-delete shape a trip item's delete uses — deleting a
  /// template item has no undo either.
  Future<void> _deleteItem(
    BuildContext context,
    WidgetRef ref,
    PackingTemplateItem item,
  ) async {
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
    if (confirmed != true) return;
    await ref.read(packingRepositoryProvider).deleteTemplateItem(item.id);
  }
}
