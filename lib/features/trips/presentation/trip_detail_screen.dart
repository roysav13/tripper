import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../expenses/presentation/trip_expenses_tab.dart';
import '../../places/presentation/trip_places_tab.dart';
import '../../vault/presentation/trip_documents_tab.dart';
import '../domain/trip.dart';
import 'trip_card.dart';
import 'trip_providers.dart';

/// Tab order is Documents, Places, Spend — keep these in sync with the
/// `tabs:`/`TabBarView` children below.
///
/// A fourth "Plan" tab (the day-by-day itinerary) lived here until
/// 2026-07-26 and was withdrawn as "currently won't do"; see
/// `docs/adr/ADR-001-itinerary-redesign.md`.
const _tabCount = 3;
const _expensesTabIndex = 2;

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

    return DefaultTabController(
      length: _tabCount,
      // While a trip is under way, spend is what you open the app for —
      // documents matter most before departure, places while planning.
      // Only `active` gets this: on an upcoming or past trip, landing on
      // Spend would bury the documents you actually came for.
      initialIndex: status == TripStatus.active ? _expensesTabIndex : 0,
      child: Scaffold(
        appBar: AppBar(
          title: Hero(
            tag: 'trip-name-${trip.id}',
            child: Material(
              type: MaterialType.transparency,
              child: Text(
                trip.name,
                style: AppTextStyles.title.copyWith(color: colors.inkPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (action) => _onMenu(context, ref, trip, action),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text(l10n.menuEdit),
                ),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(
                    trip.archived ? l10n.menuUnarchive : l10n.menuArchive,
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
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            TabBar(
              labelColor: colors.inkPrimary,
              unselectedLabelColor: colors.inkMuted,
              indicatorColor: colors.accent,
              labelStyle: AppTextStyles.label,
              // Fixed (non-scrollable) so the tabs share the width evenly
              // and each label sits centred in its slot.
              tabs: [
                Tab(text: l10n.tabDocuments),
                Tab(text: l10n.tabPlacesInTrip),
                Tab(text: l10n.tabExpenses),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  TripDocumentsTab(trip: trip),
                  TripPlacesTab(trip: trip),
                  TripExpensesTab(trip: trip),
                ],
              ),
            ),
          ],
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
          await repo.deleteTrip(trip.id);
        }
    }
  }
}
