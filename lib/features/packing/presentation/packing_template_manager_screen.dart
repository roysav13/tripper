import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/packing_template.dart';
import 'packing_providers.dart';
import 'packing_template_editor_screen.dart';
import 'packing_template_name_dialog.dart';

enum _TemplateAction { rename, delete }

class PackingTemplateManagerScreen extends ConsumerWidget {
  const PackingTemplateManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final asyncTemplates = ref.watch(packingTemplatesProvider);
    final templates =
        asyncTemplates.valueOrNull ?? const <PackingTemplate>[];
    // "Genuinely empty" is only knowable once the stream has emitted — a
    // still-loading or errored stream must not masquerade as an empty list.
    final isEmpty = asyncTemplates.hasValue && templates.isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.packingTemplatesTitle)),
      floatingActionButton: templates.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _create(context, ref),
              child: const Icon(Icons.add),
            ),
      body: _body(context, ref, l10n, asyncTemplates, templates, isEmpty),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AsyncValue<List<PackingTemplate>> asyncTemplates,
    List<PackingTemplate> templates,
    bool isEmpty,
  ) {
    if (asyncTemplates.hasError) {
      return ErrorState(onRetry: () => ref.invalidate(packingTemplatesProvider));
    }
    if (isEmpty) {
      return EmptyState(
        icon: Icons.checklist_outlined,
        title: l10n.packingTemplatesEmptyTitle,
        body: l10n.packingTemplatesEmptyBody,
        ctaLabel: l10n.packingTemplatesEmptyCta,
        onCta: () => _create(context, ref),
      );
    }
    if (!asyncTemplates.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.separated(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      itemCount: templates.length,
      separatorBuilder: (context, i) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => _row(context, ref, templates[i]),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, PackingTemplate template) {
    final l10n = AppLocalizations.of(context)!;
    final itemCount =
        ref.watch(packingTemplateItemsProvider(template.id)).valueOrNull?.length ??
            0;
    return ListTile(
      title: Text(template.name),
      subtitle: Text(l10n.templateItemCount(itemCount)),
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (context) =>
              PackingTemplateEditorScreen(templateId: template.id),
        ),
      ),
      trailing: PopupMenuButton<_TemplateAction>(
        onSelected: (action) {
          switch (action) {
            case _TemplateAction.rename:
              _rename(context, ref, template);
            case _TemplateAction.delete:
              _delete(context, ref, template);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _TemplateAction.rename,
            child: Text(l10n.menuRename),
          ),
          PopupMenuItem(
            value: _TemplateAction.delete,
            child: Text(l10n.menuDelete),
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await promptTemplateName(
      context,
      title: l10n.newTemplateDialogTitle,
      confirmLabel: l10n.save,
    );
    if (name == null) return;
    await ref.read(packingRepositoryProvider).createTemplate(name: name);
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    PackingTemplate template,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await promptTemplateName(
      context,
      title: l10n.renameTemplateDialogTitle,
      confirmLabel: l10n.save,
      initial: template.name,
    );
    if (name == null) return;
    await ref
        .read(packingRepositoryProvider)
        .renameTemplate(template.id, name);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PackingTemplate template,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTemplateTitle),
        content: Text(l10n.deleteTemplateBody),
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
    await repo.deleteTemplate(template.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.templateDeleted)));
  }
}
