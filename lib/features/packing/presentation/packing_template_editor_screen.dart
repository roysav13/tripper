import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final templates = ref.watch(packingTemplatesProvider).valueOrNull ?? const [];
    final template = templates.where((t) => t.id == templateId).firstOrNull;
    final items =
        ref.watch(packingTemplateItemsProvider(templateId)).valueOrNull ??
            const [];

    return Scaffold(
      appBar: AppBar(title: Text(template?.name ?? '')),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            showPackingItemFormSheet(context, templateId: templateId),
        child: const Icon(Icons.add),
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.checklist_outlined,
              title: l10n.packingEmptyTitle,
              body: l10n.packingEmptyBody,
              ctaLabel: l10n.packingEmptyCta,
              onCta: () =>
                  showPackingItemFormSheet(context, templateId: templateId),
            )
          : _list(context, ref, items),
    );
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
                      onPressed: () => ref
                          .read(packingRepositoryProvider)
                          .deleteTemplateItem(item.id),
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
}
