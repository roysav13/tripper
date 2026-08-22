import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/generated_cover_gradient.dart';
import '../../../core/widgets/auto_direction_text.dart';
import '../../../core/widgets/glass_chrome.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../expenses/presentation/trip_expenses_tab.dart';
import '../../journal/presentation/trip_journal_tab.dart';
import '../../packing/presentation/trip_packing_tab.dart';
import '../../places/presentation/trip_places_tab.dart';
import '../../vault/presentation/trip_documents_tab.dart';
import '../domain/trip.dart';
import 'trip_card.dart';
import 'trip_providers.dart';

/// Tab order is Documents, Places, Spend, Journal, Packing — keep these
/// in sync with the `tabs:`/`TabBarView` children below.
///
/// A "Plan" tab (the day-by-day itinerary) lived in this fourth slot until
/// 2026-07-26 and was withdrawn as "currently won't do"; see
/// `docs/adr/ADR-001-itinerary-redesign.md`. Journal is unrelated new work
/// that happens to reuse the freed slot. Packing (2026-08-22) is a new
/// fifth tab, not a slot reuse.
const _tabCount = 5;
const _expensesTabIndex = 2;

const _coverHeight = 160.0;
const _tabBarOverlap = 28.0;

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final trips = ref.watch(tripListProvider).valueOrNull;
    final trip = trips?.where((t) => t.id == tripId).firstOrNull;

    if (trips == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    if (trip == null) {
      // Deleted while open — leave gracefully.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && context.canPop()) context.pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final today = ref.watch(clockProvider)();
    final status = bucketTrip(trip, today);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DefaultTabController(
        length: _tabCount,
        // While a trip is under way, spend is what you open the app for —
        // documents matter most before departure, places while planning.
        // Only `active` gets this: on an upcoming or past trip, landing on
        // Spend would bury the documents you actually came for.
        initialIndex: status == TripStatus.active ? _expensesTabIndex : 0,
        child: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  // Reserves the tab bar's protrusion INSIDE the Stack's own
                  // bounds so it stays hit-testable — RenderBox.hitTest gates
                  // on the Stack's own reported size, and Clip.none only
                  // affects painting, not hit-testing.
                  const SizedBox(
                    height: _coverHeight + _tabBarOverlap,
                    width: double.infinity,
                  ),
                  // Shares a tag with TripCard's cover hero (Task 3).
                  Hero(
                    tag: 'trip-cover-${trip.id}',
                    child: SizedBox(
                      height: _coverHeight,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _CoverBackground(trip: trip, colors: colors),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.dark.paper.withValues(alpha: 0.55),
                                  AppColors.dark.paper.withValues(alpha: 0.85),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: 0,
                    start: 0,
                    end: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                        child: GlassChrome(
                          borderRadius:
                              BorderRadius.circular(AppShape.pillRadius),
                          tint: AppColors.dark.surface,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                // BackButton (not a raw Icon) so the glyph
                                // still auto-mirrors for RTL — building the
                                // topbar by hand must not lose what AppBar
                                // gave us for free.
                                BackButton(
                                  color: AppColors.dark.inkPrimary,
                                  onPressed: () => context.pop(),
                                ),
                                Expanded(
                                  child: Hero(
                                    tag: 'trip-name-${trip.id}',
                                    child: Material(
                                      type: MaterialType.transparency,
                                      child: AutoDirectionText(
                                        trip.name,
                                        style: AppTextStyles.title.copyWith(
                                          color: AppColors.dark.inkPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert,
                                    color: AppColors.dark.inkPrimary,
                                  ),
                                  onSelected: (action) =>
                                      _onMenu(context, ref, trip, action),
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text(l10n.menuEdit),
                                    ),
                                    PopupMenuItem(
                                      value: 'archive',
                                      child: Text(
                                        trip.archived
                                            ? l10n.menuUnarchive
                                            : l10n.menuArchive,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(l10n.menuDelete),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: AppSpacing.lg,
                    end: AppSpacing.lg,
                    bottom: 0,
                    child: GlassChrome(
                      borderRadius: BorderRadius.circular(AppShape.radius),
                      child: TabBar(
                        labelColor: colors.inkPrimary,
                        unselectedLabelColor: colors.inkMuted,
                        indicatorColor: colors.accent,
                        labelStyle: AppTextStyles.label,
                        // Scrollable: five tabs no longer fit evenly at
                        // every width, so labels scroll instead of
                        // compacting/wrapping.
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: [
                          Tab(text: l10n.tabDocuments),
                          Tab(text: l10n.tabPlacesInTrip),
                          Tab(text: l10n.tabExpenses),
                          Tab(text: l10n.tabJournal),
                          Tab(text: l10n.tabPacking),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // The Stack above now reports its own full height
              // (_coverHeight + _tabBarOverlap) directly, so no extra
              // compensation for the tab bar's overlap is needed here.
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: MonoText(
                  '${TripDateFormatter.line(l10n, trip)}'
                  ' · ${trip.destinations.join(' → ')}'
                  '${status == TripStatus.active ? ' · ${activeDayLabel(l10n, trip, today)}' : ''}',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: TabBarView(
                  // Journal's globe needs full ownership of horizontal drags
                  // to rotate — a swipeable TabBarView competes for the same
                  // gesture and wins, so tabs are tap-only everywhere.
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    TripDocumentsTab(trip: trip),
                    TripPlacesTab(trip: trip),
                    TripExpensesTab(trip: trip),
                    TripJournalTab(trip: trip),
                    TripPackingTab(trip: trip),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
    String action,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.read(tripRepositoryProvider);
    switch (action) {
      case 'edit':
        await context.push('/trips/${trip.id}/edit', extra: trip);
      case 'archive':
        await repo.setArchived(trip.id, archived: !trip.archived);
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.deleteTripTitle),
            content: Text(l10n.deleteTripBody),
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
          if (trip.coverPhotoPath != null) {
            try {
              await ref
                  .read(coverPhotoFileServiceProvider)
                  .delete(trip.coverPhotoPath!);
            } catch (_) {
              // Best-effort cleanup only.
            }
          }
          await repo.deleteTrip(trip.id);
        }
    }
  }
}

class _CoverBackground extends StatelessWidget {
  const _CoverBackground({required this.trip, required this.colors});

  final Trip trip;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final path = trip.coverPhotoPath;
    if (path != null) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: generatedCoverGradient(trip.id, colors),
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: generatedCoverGradient(trip.id, colors),
      ),
    );
  }
}
