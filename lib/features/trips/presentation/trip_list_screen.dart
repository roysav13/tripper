import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/settings/settings_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../../places/presentation/place_providers.dart';
import '../../places/presentation/place_visit_actions.dart';
import '../domain/trip.dart';
import 'trip_card.dart';
import 'trip_providers.dart';

class TripListScreen extends ConsumerWidget {
  const TripListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final asyncTrips = ref.watch(tripListProvider);
    final buckets = ref.watch(bucketedTripsProvider);
    final archived = ref.watch(archivedTripsProvider);
    final today = ref.watch(clockProvider)();

    // Launch behavior (SPEC §3.1.1): one active trip -> open it, once.
    ref.listen(tripListProvider, (previous, next) {
      final trips = next.valueOrNull;
      if (trips == null) return;
      if (!ref.read(launchRedirectDoneProvider)) {
        ref.read(launchRedirectDoneProvider.notifier).state = true;
        final path = launchRedirectPath(trips, ref.read(clockProvider)());
        if (path != null && context.mounted) context.push(path);
      }
      // Trip over -> offer the one-time bulk "mark visited" (SPEC M3).
      unawaited(_maybeShowCompletionPrompt(context, ref, trips));
    });

    final isEmpty = asyncTrips.hasValue &&
        buckets.values.every((b) => b.isEmpty) &&
        archived.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: colors.inkMuted,
            ),
            tooltip: l10n.themeToggleTooltip,
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: colors.inkMuted),
            tooltip: l10n.settingsTitle,
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/trips/new'),
        backgroundColor: colors.accent,
        foregroundColor: colors.surface,
        tooltip: l10n.tripsEmptyCta,
        child: const Icon(Icons.add),
      ),
      body: _body(
        context,
        ref,
        l10n,
        asyncTrips,
        isEmpty,
        buckets,
        archived,
        today,
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AsyncValue<List<Trip>> asyncTrips,
    bool isEmpty,
    Map<TripStatus, List<Trip>> buckets,
    List<Trip> archived,
    DateTime today,
  ) {
    // M4.2 — states audit: a stream failure used to render an
    // indistinguishable blank list (isEmpty only turns true on a
    // *successful* empty load), not an explained error.
    if (asyncTrips.hasError) {
      return ErrorState(onRetry: () => ref.invalidate(tripListProvider));
    }
    if (isEmpty) {
      return EmptyState(
        icon: Icons.luggage_outlined,
        title: l10n.tripsEmptyTitle,
        body: l10n.tripsEmptyBody,
        ctaLabel: l10n.tripsEmptyCta,
        onCta: () => context.push('/trips/new'),
      );
    }
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        end: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: 88,
      ),
      children: [
        // M4.5 — quiet nudge, not a notification; disappears for good the
        // moment a real export happens (settings_service).
        if (!ref.watch(hasExportedProvider)) ...[
          _BackupReminderBanner(colors: colors, l10n: l10n),
          const SizedBox(height: AppSpacing.md),
        ],
        ..._section(
          context,
          l10n.sectionActive,
          buckets[TripStatus.active]!,
          TripStatus.active,
          today,
        ),
        ..._section(
          context,
          l10n.sectionUpcoming,
          buckets[TripStatus.upcoming]!,
          TripStatus.upcoming,
          today,
        ),
        ..._section(
          context,
          l10n.sectionPlanned,
          buckets[TripStatus.planned]!,
          TripStatus.planned,
          today,
        ),
        ..._section(
          context,
          l10n.sectionPast,
          buckets[TripStatus.past]!,
          TripStatus.past,
          today,
        ),
        ..._section(
          context,
          l10n.sectionArchived,
          archived,
          TripStatus.past,
          today,
        ),
      ],
    );
  }

  Future<void> _maybeShowCompletionPrompt(
    BuildContext context,
    WidgetRef ref,
    List<Trip> trips,
  ) async {
    if (ref.read(completionPromptActiveProvider)) return;
    final today = ref.read(clockProvider)();
    final candidate = trips
        .where(
          (t) =>
              !t.archived &&
              !t.completionPromptShown &&
              t.endDate != null &&
              bucketTrip(t, today) == TripStatus.past,
        )
        .firstOrNull;
    if (candidate == null) return;
    ref.read(completionPromptActiveProvider.notifier).state = true;
    try {
      final places = await ref
          .read(placeRepositoryProvider)
          .watchForTrip(candidate.id)
          .first;
      final wishlist = places.where((p) => !p.isVisited).toList();
      // Offered once, whether or not there was anything to mark.
      await ref
          .read(tripRepositoryProvider)
          .markCompletionPromptShown(candidate.id);
      if (wishlist.isEmpty || !context.mounted) return;

      final l10n = AppLocalizations.of(context)!;
      final selected = {for (final p in wishlist) p.id};
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(l10n.tripCompleteTitle),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.tripCompleteBody(candidate.name)),
                  const SizedBox(height: AppSpacing.sm),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final place in wishlist)
                          CheckboxListTile(
                            dense: true,
                            title: Text(place.name),
                            value: selected.contains(place.id),
                            onChanged: (checked) => setState(() {
                              if (checked ?? false) {
                                selected.add(place.id);
                              } else {
                                selected.remove(place.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.tripCompleteSkip),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.tripCompleteConfirm),
              ),
            ],
          ),
        ),
      );
      if ((confirmed ?? false) && selected.isNotEmpty) {
        await markPlacesVisited(
          ref,
          wishlist.where((p) => selected.contains(p.id)).toList(),
          candidate.endDate!,
        );
      }
    } finally {
      ref.read(completionPromptActiveProvider.notifier).state = false;
    }
  }

  List<Widget> _section(
    BuildContext context,
    String label,
    List<Trip> trips,
    TripStatus status,
    DateTime today,
  ) {
    if (trips.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsetsDirectional.only(
          top: AppSpacing.md,
          bottom: AppSpacing.sm,
        ),
        child: SectionLabel(label),
      ),
      for (final trip in trips)
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
          child: TripCard(
            trip: trip,
            status: status,
            today: today,
            onTap: () => context.push('/trips/${trip.id}'),
          ),
        ),
    ];
  }
}

class _BackupReminderBanner extends StatelessWidget {
  const _BackupReminderBanner({required this.colors, required this.l10n});

  final AppColors colors;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      borderColor: colors.warning,
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_outlined, size: 18, color: colors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.backupReminderBody,
                  style: TextStyle(fontSize: 13, color: colors.warning),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  // Default TextButton sizing on purpose — accessibility_
                  // test.dart's androidTapTargetGuideline runs over this
                  // whole screen, and a shrink-wrapped button would fail
                  // the same ≥48dp rule M4.3 just got verified for.
                  child: TextButton(
                    onPressed: () => context.push('/settings'),
                    child: Text(l10n.backupReminderCta),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
