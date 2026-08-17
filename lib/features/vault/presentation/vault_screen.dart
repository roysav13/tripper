import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/filtering/filter_engine.dart';
import '../../../core/filtering/filter_sort_config.dart';
import '../../../core/filtering/filter_sort_controller.dart';
import '../../../core/security/vault_lock.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/filtering/active_filter_strip.dart';
import '../../../core/widgets/filtering/filter_sort_button.dart';
import '../../../core/widgets/filtering/filter_sort_sheet.dart';
import '../../../core/widgets/filtering/filter_sort_view.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/document.dart';
import '../domain/document_sort.dart';
import '../domain/expiry_checker.dart';
import 'document_actions_sheet.dart';
import 'document_filter_config.dart';
import 'document_form_sheet.dart';
import 'document_providers.dart';
import 'document_widgets.dart';
import 'show_code_screen.dart';

const _scope = 'vault';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
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
    final config = buildDocumentFilterSortConfig(l10n);

    return FilterSortView<Document, DocumentSortField>(
      itemsProvider: vaultDocumentsProvider,
      controllerFamily: documentFilterSortProvider,
      scope: _scope,
      config: config,
      builder: (context, all, visible, state) => _VaultScreenBody(
        all: all,
        visible: visible,
        sortState: state,
        config: config,
      ),
    );
  }
}

class _VaultScreenBody extends ConsumerWidget {
  const _VaultScreenBody({
    required this.all,
    required this.visible,
    required this.sortState,
    required this.config,
  });

  final List<Document> all;
  final List<Document> visible;
  final FilterSortState<DocumentSortField> sortState;
  final FilterSortConfig<Document, DocumentSortField> config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final asyncDocs = ref.watch(vaultDocumentsProvider);
    final pinned = ref.watch(pinnedDocumentsProvider);
    final today = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabVault),
        actions: [
          if (all.isNotEmpty)
            FilterSortButton(
              active: !sortState.selection.isEmpty,
              onPressed: () => showFilterSortSheet<Document, DocumentSortField>(
                context,
                itemsProvider: vaultDocumentsProvider,
                controllerFamily: documentFilterSortProvider,
                scope: _scope,
                config: config,
              ),
            ),
          IconButton(
            icon: Icon(Icons.add, color: colors.accent),
            tooltip: l10n.vaultEmptyCta,
            onPressed: () => showDocumentFormSheet(context),
          ),
        ],
      ),
      body: _body(context, ref, l10n, asyncDocs, pinned, today),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AsyncValue<List<Document>> asyncDocs,
    List<Document> pinned,
    DateTime today,
  ) {
    // M4.2 — states audit: same gap as trips/places — a stream failure
    // used to fall straight through to an unexplained empty screen.
    if (asyncDocs.hasError) {
      return ErrorState(onRetry: () => ref.invalidate(vaultDocumentsProvider));
    }
    if (asyncDocs.hasValue && all.isEmpty) {
      return EmptyState(
        icon: Icons.folder_outlined,
        title: l10n.vaultEmptyTitle,
        body: l10n.vaultEmptyBody,
        ctaLabel: l10n.vaultEmptyCta,
        onCta: () => showDocumentFormSheet(context),
      );
    }
    // No "filtered to zero" empty state here (unlike Places): Vault has
    // only the one category facet, and its chips are only ever built from
    // categories present in `all` — so any selection always keeps at
    // least one document. That combination is only reachable once a
    // second, independent facet exists.
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
        if (!sortState.selection.isEmpty) ...[
          _activeFilterStrip(ref),
          const SizedBox(height: AppSpacing.sm),
        ],
        // Grouped by category, one card per document (trips-list
        // style, per user feedback). Sort order (from the filter/sort
        // sheet) determines the order of documents within each
        // section — the sections themselves stay fixed.
        for (final category in DocumentCategory.values)
          ..._categorySection(
            context,
            ref,
            l10n,
            category,
            [
              for (final d in visible)
                if (d.category == category) d,
            ],
            today,
          ),
      ],
    );
  }

  Widget _activeFilterStrip(WidgetRef ref) {
    final active = <ActiveFilterEntry>[];
    for (final facet in config.facets) {
      final available = availableFacetValues(all, facet);
      for (final valueId in sortState.selection.valuesFor(facet.id)) {
        for (final value in available) {
          if (value.id == valueId) {
            active.add(ActiveFilterEntry(facetId: facet.id, value: value));
            break;
          }
        }
      }
    }
    final notifier = ref.read(documentFilterSortProvider(_scope).notifier);
    return ActiveFilterStrip(
      active: active,
      onRemove: notifier.removeValue,
      onClearAll: notifier.clearFilters,
    );
  }

  List<Widget> _categorySection(
    BuildContext context,
    WidgetRef ref,
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
