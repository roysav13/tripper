import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/domain/trip.dart';
import '../domain/document.dart';
import '../domain/expiry_checker.dart';
import 'document_actions_sheet.dart';
import 'document_form_sheet.dart';
import 'document_providers.dart';
import 'document_widgets.dart';

/// Documents tab inside a trip's detail screen (fills the M1 shell).
class TripDocumentsTab extends ConsumerWidget {
  const TripDocumentsTab({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final asyncDocs = ref.watch(tripDocumentsProvider(trip.id));
    final docs = asyncDocs.valueOrNull ?? const <Document>[];
    final risky = docs.where((d) => ExpiryChecker.isRiskyForTrip(d, trip));

    if (asyncDocs.hasValue && docs.isEmpty) {
      return EmptyState(
        icon: Icons.folder_outlined,
        title: l10n.tripDocsEmptyTitle,
        body: l10n.tripDocsEmptyBody,
        ctaLabel: l10n.vaultEmptyCta,
        onCta: () => showDocumentFormSheet(context, tripId: trip.id),
      );
    }

    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        if (risky.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
            child: PaperCard(
              borderColor: colors.warning,
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 18,
                    color: colors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.expiryTripWarning(risky.first.title),
                      style: TextStyle(fontSize: 13, color: colors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ),
        for (final doc in docs)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: DocumentRowTile(
              doc: doc,
              warning: ExpiryChecker.isRiskyForTrip(doc, trip),
              onTap: () => showDocumentActionsSheet(context, ref, doc),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: Text(l10n.vaultEmptyCta),
          onPressed: () => showDocumentFormSheet(context, tripId: trip.id),
        ),
      ],
    );
  }
}
