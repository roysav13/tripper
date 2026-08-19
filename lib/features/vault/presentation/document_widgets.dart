import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/auto_direction_text.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/document.dart';

IconData categoryIcon(DocumentCategory category) => switch (category) {
      DocumentCategory.passportId => Icons.badge_outlined,
      DocumentCategory.visa => Icons.approval_outlined,
      DocumentCategory.flight => Icons.flight_outlined,
      DocumentCategory.stay => Icons.hotel_outlined,
      DocumentCategory.insurance => Icons.health_and_safety_outlined,
      DocumentCategory.transport => Icons.directions_bus_outlined,
      DocumentCategory.other => Icons.description_outlined,
    };

String categoryLabel(AppLocalizations l10n, DocumentCategory category) =>
    switch (category) {
      DocumentCategory.passportId => l10n.catPassport,
      DocumentCategory.visa => l10n.catVisa,
      DocumentCategory.flight => l10n.catFlight,
      DocumentCategory.stay => l10n.catStay,
      DocumentCategory.insurance => l10n.catInsurance,
      DocumentCategory.transport => l10n.catTransport,
      DocumentCategory.other => l10n.catOther,
    };

String _expiryText(AppLocalizations l10n, DateTime expiry) =>
    l10n.expiryShort(DateFormat('dd/MM/yyyy', l10n.localeName).format(expiry));

/// Mono metadata line: category-specific details + expiry.
String documentMetaLine(AppLocalizations l10n, Document doc) {
  final parts = <String>[
    categoryLabel(l10n, doc.category),
    ...doc.details.values.where((v) => v.trim().isNotEmpty),
    if (doc.expiryDate != null) _expiryText(l10n, doc.expiryDate!),
    if (!doc.hasFile) l10n.manualRecord,
  ];
  return parts.join(' · ');
}

/// A category section's collapsible header: the category label, a count
/// of the documents in it, and an expand/collapse chevron. Tapping
/// anywhere on the header toggles [expanded]. Mirrors
/// [ExpenseGroupHeader]'s interaction so the two collapsible-list
/// patterns in the app stay consistent.
class DocumentCategoryHeader extends StatelessWidget {
  const DocumentCategoryHeader({
    super.key,
    required this.category,
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final DocumentCategory category;
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        // Minimum 48px tap target (WCAG 2.5.5 / Android a11y guidance) —
        // the header's own content is only ~34px tall.
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(
          child: Row(
            children: [
              Expanded(child: SectionLabel(categoryLabel(l10n, category))),
              MonoText(l10n.vaultCategoryCount(count), muted: true),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: colors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One document = one card (matches the trips list), used in the vault
/// and in a trip's Documents tab. A real elevated Material card with a
/// leading accent edge — coral normally, amber when the document has
/// expired (replaces the old full-border warning treatment: only the
/// edge changes color now, not the whole card outline).
class DocumentRowTile extends StatelessWidget {
  const DocumentRowTile({
    super.key,
    required this.doc,
    required this.warning,
    this.onTap,
  });

  final Document doc;
  final bool warning;
  final VoidCallback? onTap;

  static const _shape = BorderRadiusDirectional.only(
    topStart: Radius.circular(4),
    bottomStart: Radius.circular(4),
    topEnd: Radius.circular(AppShape.radius),
    bottomEnd: Radius.circular(AppShape.radius),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final edgeColor = warning ? colors.warning : colors.accent;

    return Material(
      color: colors.surface,
      elevation: 3,
      shape: const RoundedRectangleBorder(borderRadius: _shape),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(color: edgeColor, child: const SizedBox(width: 5)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(
                        categoryIcon(doc.category),
                        size: 20,
                        color: warning ? colors.warning : colors.inkSecondary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AutoDirectionText(
                              doc.title,
                              style: AppTextStyles.body.copyWith(
                                color: colors.inkPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            MonoText(
                              documentMetaLine(l10n, doc),
                              color: warning ? colors.warning : null,
                            ),
                          ],
                        ),
                      ),
                      if (doc.isPinned)
                        Icon(
                          Icons.push_pin_outlined,
                          size: 16,
                          color: colors.accent,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Documents grouped into per-category sections, each collapsible via
/// its [DocumentCategoryHeader]. Shared by the top-level Vault screen and
/// a trip's Documents tab so both document lists collapse the same way
/// once a long trip's documents pile up. Category order follows
/// [DocumentCategory.values]; order within a category follows
/// [documents] as passed in, so callers control sort order upstream.
/// Collapse state is in-memory only (per widget instance) and starts
/// with every non-empty category expanded.
class CategoryGroupedDocuments extends StatefulWidget {
  const CategoryGroupedDocuments({
    super.key,
    required this.documents,
    required this.warningFor,
    required this.onTap,
  });

  final List<Document> documents;
  final bool Function(Document doc) warningFor;
  final void Function(Document doc) onTap;

  @override
  State<CategoryGroupedDocuments> createState() =>
      _CategoryGroupedDocumentsState();
}

class _CategoryGroupedDocumentsState extends State<CategoryGroupedDocuments> {
  final Set<DocumentCategory> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final category in DocumentCategory.values) {
      final docs = [
        for (final d in widget.documents)
          if (d.category == category) d,
      ];
      if (docs.isEmpty) continue;
      final isCollapsed = _collapsed.contains(category);
      children.add(
        Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
          child: DocumentCategoryHeader(
            category: category,
            count: docs.length,
            expanded: !isCollapsed,
            onTap: () => setState(() {
              if (isCollapsed) {
                _collapsed.remove(category);
              } else {
                _collapsed.add(category);
              }
            }),
          ),
        ),
      );
      if (!isCollapsed) {
        for (final doc in docs) {
          children.add(
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
              child: DocumentRowTile(
                doc: doc,
                warning: widget.warningFor(doc),
                onTap: () => widget.onTap(doc),
              ),
            ),
          );
        }
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// Pinned quick-access card: a soft gradient wash built from the card's
/// own surface tone toward a muted `heroGradientEnd` — the same "your
/// most important documents get their own moment" idea trip covers use,
/// deliberately much softer (35% peak, not full strength) since this is
/// a document, not a photo.
class PinnedDocumentCard extends StatelessWidget {
  const PinnedDocumentCard({
    super.key,
    required this.doc,
    required this.warning,
    this.onTap,
  });

  final Document doc;
  final bool warning;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShape.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              colors.surface,
              Color.lerp(colors.surface, colors.heroGradientEnd, 0.35)!,
            ],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  categoryIcon(doc.category),
                  size: 18,
                  color: colors.accent,
                ),
                const SizedBox(height: AppSpacing.sm),
                AutoDirectionText(
                  doc.title,
                  style: AppTextStyles.label.copyWith(color: colors.inkPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                MonoText(
                  doc.expiryDate != null
                      ? _expiryText(l10n, doc.expiryDate!)
                      : categoryLabel(l10n, doc.category),
                  color: warning ? colors.warning : null,
                  muted: !warning,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
