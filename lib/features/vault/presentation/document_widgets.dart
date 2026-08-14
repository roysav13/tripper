import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/auto_direction_text.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/paper_card.dart';
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

/// Category filter chips — a controlled widget, all state lives in the
/// parent screen (mirrors places' PlaceFilterBar). Only categories
/// actually present in [docs] render a chip, so there's never a dead-end
/// filter option.
class DocumentFilterBar extends StatelessWidget {
  const DocumentFilterBar({
    super.key,
    required this.docs,
    required this.selectedCategories,
    required this.onCategoriesChanged,
  });

  final List<Document> docs;
  final Set<DocumentCategory> selectedCategories;
  final ValueChanged<Set<DocumentCategory>> onCategoriesChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = {for (final d in docs) d.category}.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    if (categories.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final category in categories)
          FilterChip(
            avatar: Icon(categoryIcon(category), size: 16),
            label: Text(categoryLabel(l10n, category)),
            selected: selectedCategories.contains(category),
            onSelected: (selected) => onCategoriesChanged(
              selected
                  ? {...selectedCategories, category}
                  : selectedCategories.where((c) => c != category).toSet(),
            ),
          ),
      ],
    );
  }
}

/// One document = one card (matches the trips list), used in the vault
/// and in a trip's Documents tab.
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    return PaperCard(
      onTap: onTap,
      borderColor: warning ? colors.warning : null,
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
            Icon(Icons.push_pin_outlined, size: 16, color: colors.accent),
        ],
      ),
    );
  }
}

/// Pinned quick-access card: light surface, teal border (revised mockup).
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
    return PaperCard(
      borderColor: colors.accent,
      onTap: onTap,
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(categoryIcon(doc.category), size: 18, color: colors.accent),
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
    );
  }
}
