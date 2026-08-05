import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/domain/trip.dart';
import '../domain/journal_entry.dart';
import 'journal_entry_form_sheet.dart';
import 'journal_globe.dart';
import 'journal_map_view.dart';
import 'journal_providers.dart';
import 'journal_widgets.dart';

/// Journal tab inside a trip's detail screen: a globe of this trip's
/// visited places, a timeline of logged entries below it, and a map
/// sub-view toggle (entries as circles/photo-markers connected by a
/// polyline, in chronological order).
class TripJournalTab extends ConsumerWidget {
  const TripJournalTab({
    super.key,
    required this.trip,
    this.renderGlobe = true,
    this.renderMap = true,
  });

  final Trip trip;

  /// False in widget tests: the globe needs a GPU shader surface, same
  /// reasoning as JournalGlobe's own `renderGlobe` seam.
  final bool renderGlobe;

  /// False in widget tests: Google Maps needs a platform view, same
  /// reasoning as JournalMapView's own `renderMap` seam.
  final bool renderMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final asyncEntries = ref.watch(tripJournalProvider(trip.id));
    final entries = asyncEntries.valueOrNull ?? const <JournalEntry>[];
    final visitedPlaces = ref.watch(tripVisitedPlacesProvider(trip.id));
    final showMap = ref.watch(journalMapModeProvider);

    if (asyncEntries.hasValue && entries.isEmpty) {
      return EmptyState(
        icon: Icons.auto_stories_outlined,
        title: l10n.journalEmptyTitle,
        body: l10n.journalEmptyBody,
        ctaLabel: l10n.journalAddEntryCta,
        onCta: () => showJournalEntryFormSheet(context, tripId: trip.id),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: SectionLabel(
                  l10n.journalStatsLine(entries.length, visitedPlaces.length),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: l10n.journalAddEntryCta,
                onPressed: () =>
                    showJournalEntryFormSheet(context, tripId: trip.id),
              ),
              IconButton(
                icon: Icon(showMap ? Icons.timeline : Icons.map_outlined),
                tooltip: showMap ? l10n.listViewToggle : l10n.mapViewToggle,
                onPressed: () =>
                    ref.read(journalMapModeProvider.notifier).update((v) => !v),
              ),
            ],
          ),
        ),
        // The globe owns this area — no ancestor scrollable wraps it, so
        // every pan/tap on it drives the globe, never a parent scroll.
        Expanded(
          child: showMap
              ? JournalMapView(entries: entries, renderMap: renderMap)
              : Column(
                  // stretch: without this, children only get a loose width
                  // constraint (Column's default is center) — the globe
                  // needs a tight/bounded constraint to size itself and
                  // silently renders nothing under a loose one. The gallery
                  // ListView happened to fill width regardless, which is
                  // why only the globe went missing.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Fixed 70/30 split — the globe is the dominant element,
                    // the gallery a slim strip beneath it.
                    Expanded(
                      flex: 7,
                      child: JournalGlobe(
                        entries: entries,
                        renderGlobe: renderGlobe,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: JournalGalleryTimeline(
                        entries: entries,
                        onEdit: (entry) => showJournalEntryFormSheet(
                          context,
                          tripId: trip.id,
                          existing: entry,
                        ),
                        onDelete: (entry) => _confirmDelete(context, ref, entry),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    JournalEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.journalDeleteEntryTitle),
        content: Text(l10n.journalDeleteEntryBody),
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
    if (confirmed ?? false) {
      await ref.read(journalRepositoryProvider).deleteEntry(entry.id);
    }
  }
}
