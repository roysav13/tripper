import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/security/vault_lock.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/document.dart';
import '../domain/document_sort.dart';
import '../domain/expiry_checker.dart';
import 'document_actions_sheet.dart';
import 'document_form_sheet.dart';
import 'document_providers.dart';
import 'document_widgets.dart';
import 'show_code_screen.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  Set<DocumentCategory> _categoryFilter = {};
  DocumentSortOrder _sortOrder = DocumentSortOrder.createdDate;

  @override
  void initState() {
    super.initState();
    // Auto-prompt on tab open; the button below retries after a failure.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    final l10n = AppLocalizations.of(context)!;
    await ref
        .read(vaultLockProvider.notifier)
        .ensureUnlocked(l10n.unlockReason);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final unlocked = ref.watch(vaultLockProvider);
    if (!unlocked) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tabVault)),
        body: EmptyState(
          icon: Icons.lock_outline,
          title: l10n.vaultLockedTitle,
          body: l10n.vaultLockedBody,
          ctaLabel: l10n.unlockCta,
          onCta: _unlock,
        ),
      );
    }
    final asyncDocs = ref.watch(vaultDocumentsProvider);
    final docs = asyncDocs.valueOrNull ?? const <Document>[];
    final pinned = ref.watch(pinnedDocumentsProvider);
    final today = ref.watch(clockProvider)();

    // Same stranded-filter guard as PlacesScreen: if the last document in
    // a selected category is edited/deleted, its chip disappears — prune
    // the selection against what's still present so the list can't be
    // left empty with no visible way to recover.
    final availableCategories = {for (final d in docs) d.category};
    final prunedCategories = _categoryFilter.intersection(availableCategories);
    if (prunedCategories.length != _categoryFilter.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _categoryFilter = prunedCategories);
      });
    }
    final visibleDocs = sortDocuments(
      filterDocumentsByCategory(docs, prunedCategories),
      _sortOrder,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabVault),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: colors.accent),
            tooltip: l10n.vaultEmptyCta,
            onPressed: () => showDocumentFormSheet(context),
          ),
        ],
      ),
      body: _body(
        context,
        ref,
        l10n,
        asyncDocs,
        docs,
        visibleDocs,
        prunedCategories,
        pinned,
        today,
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AsyncValue<List<Document>> asyncDocs,
    List<Document> docs,
    List<Document> visibleDocs,
    Set<DocumentCategory> categoryFilter,
    List<Document> pinned,
    DateTime today,
  ) {
    // M4.2 — states audit: same gap as trips/places — a stream failure
    // used to fall straight through to an unexplained empty screen.
    if (asyncDocs.hasError) {
      return ErrorState(onRetry: () => ref.invalidate(vaultDocumentsProvider));
    }
    if (asyncDocs.hasValue && docs.isEmpty) {
      return EmptyState(
        icon: Icons.folder_outlined,
        title: l10n.vaultEmptyTitle,
        body: l10n.vaultEmptyBody,
        ctaLabel: l10n.vaultEmptyCta,
        onCta: () => showDocumentFormSheet(context),
      );
    }
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        if (pinned.isNotEmpty) ...[
          SectionLabel(l10n.vaultPinnedSection),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.9,
            children: [
              for (final doc in pinned)
                PinnedDocumentCard(
                  doc: doc,
                  // Red border = actually expired only (2026-07-23) —
                  // showing it for "expiring soon" too made every
                  // near-term document look like an error. The
                  // notice-window concept still exists for the M5.2
                  // expiry notification, just not for this border.
                  warning: ExpiryChecker.isExpired(doc, today),
                  // Fast path: pinned boarding pass -> gate screen
                  // in one tap. Everything else -> actions.
                  onTap: () => ShowCodeScreen.canShow(doc)
                      ? ShowCodeScreen.open(context, doc)
                      : showDocumentActionsSheet(context, ref, doc),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        DocumentFilterBar(
          docs: docs,
          selectedCategories: categoryFilter,
          onCategoriesChanged: (v) => setState(() => _categoryFilter = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<DocumentSortOrder>(
          segments: [
            ButtonSegment(
              value: DocumentSortOrder.createdDate,
              label: Text(l10n.vaultSortCreated),
            ),
            ButtonSegment(
              value: DocumentSortOrder.relevantDate,
              label: Text(l10n.vaultSortRelevant),
            ),
          ],
          selected: {_sortOrder},
          showSelectedIcon: false,
          onSelectionChanged: (selection) =>
              setState(() => _sortOrder = selection.first),
        ),
        // Grouped by category, one card per document (trips-list
        // style, per user feedback). Sort order (from the segmented
        // control above) determines the order of documents within each
        // section — the sections themselves stay fixed.
        for (final category in DocumentCategory.values)
          ..._categorySection(
            l10n,
            category,
            [
              for (final d in visibleDocs)
                if (d.category == category) d,
            ],
            today,
          ),
      ],
    );
  }

  List<Widget> _categorySection(
    AppLocalizations l10n,
    DocumentCategory category,
    List<Document> docs,
    DateTime today,
  ) {
    if (docs.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsetsDirectional.only(
          top: AppSpacing.md,
          bottom: AppSpacing.sm,
        ),
        child: SectionLabel(categoryLabel(l10n, category)),
      ),
      for (final doc in docs)
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
          child: DocumentRowTile(
            doc: doc,
            // Red border = actually expired only (2026-07-23) — showing it
            // for "expiring soon" too made every near-term document look
            // like an error. The notice-window concept still exists for
            // the M5.2 expiry notification, just not for this border.
            warning: ExpiryChecker.isExpired(doc, today),
            onTap: () => showDocumentActionsSheet(context, ref, doc),
          ),
        ),
    ];
  }
}
