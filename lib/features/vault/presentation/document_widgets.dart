import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/ticket_card.dart';
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

/// Fixed per-category identity color (SPEC §4.2/§4.4, M7 restyle) — the
/// same `tripPalette` hues trips use, but assigned by real-world
/// association rather than by raw enum index, so the mapping reads as a
/// deliberate choice rather than an arbitrary one: passports are
/// traditionally navy (Indigo), a hotel stay feels warm (Marigold),
/// insurance reads as safety (Moss), flights read sky-blue (Cobalt). Two
/// palette entries (Berry, Harbor teal) are shared — Harbor teal doubles
/// as "Other"/default, matching its role as the app's default trip color.
Color documentCategoryAccent(AppColors colors, DocumentCategory category) {
  final index = switch (category) {
    DocumentCategory.passportId => 3, // Indigo
    DocumentCategory.visa => 5, // Plum
    DocumentCategory.flight => 6, // Cobalt
    DocumentCategory.stay => 1, // Marigold
    DocumentCategory.insurance => 4, // Moss
    DocumentCategory.transport => 7, // Slate
    DocumentCategory.other => 0, // Harbor teal
  };
  return colors.tripPalette[index];
}

/// A document's ticket accent — a real problem (expired) overrides the
/// category's decorative identity color with the system warning color.
/// Semantic meaning always wins over decoration (hard rule #1): an
/// expired passport must never look like just another navy card.
Color documentCardAccent(
  AppColors colors,
  Document doc, {
  required bool warning,
}) =>
    warning ? colors.warning : documentCategoryAccent(colors, doc.category);

String _expiryText(AppLocalizations l10n, DateTime expiry) =>
    l10n.expiryShort(DateFormat('dd/MM/yyyy').format(expiry));

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

/// One document = one ticket (matches the trips list), used in the vault
/// and in a trip's Documents tab. The stub carries the category's icon and
/// identity color — SPEC's "a flight looks different from a passport scan
/// at a glance" — with the color itself giving a second, faster signal
/// alongside the icon.
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

    return TicketCard(
      accentColor: documentCardAccent(colors, doc, warning: warning),
      onTap: onTap,
      semanticLabel: '${doc.title}. ${documentMetaLine(l10n, doc)}',
      stub: Icon(categoryIcon(doc.category), size: 26),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  doc.title,
                  style: AppTextStyles.body.copyWith(
                    color: colors.inkPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (doc.isPinned) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.push_pin_outlined, size: 16, color: colors.accent),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          MonoText(
            documentMetaLine(l10n, doc),
            color: warning ? colors.warning : null,
          ),
        ],
      ),
    );
  }
}

/// Pinned quick-access tile: the same ticket anatomy as [DocumentRowTile],
/// scaled down (narrower stub, tighter padding) to fit the 2-column
/// quick-access grid — one tap from app launch to the gate screen.
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

    final subtitle = doc.expiryDate != null
        ? _expiryText(l10n, doc.expiryDate!)
        : categoryLabel(l10n, doc.category);

    return TicketCard(
      accentColor: documentCardAccent(colors, doc, warning: warning),
      onTap: onTap,
      semanticLabel: '${doc.title}. $subtitle',
      stubWidth: 56,
      bodyPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      stub: Icon(categoryIcon(doc.category), size: 20),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            doc.title,
            style: AppTextStyles.label.copyWith(color: colors.inkPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          MonoText(
            subtitle,
            color: warning ? colors.warning : null,
            muted: !warning,
          ),
        ],
      ),
    );
  }
}
