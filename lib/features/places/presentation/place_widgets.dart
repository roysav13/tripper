import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/auto_direction_text.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/place.dart';

IconData placeCategoryIcon(PlaceCategory category) => switch (category) {
      PlaceCategory.hotel => Icons.hotel_outlined,
      PlaceCategory.restaurant => Icons.restaurant_outlined,
      PlaceCategory.coffeeShop => Icons.local_cafe_outlined,
      PlaceCategory.bar => Icons.local_bar_outlined,
      PlaceCategory.attraction => Icons.local_activity_outlined,
      PlaceCategory.museum => Icons.museum_outlined,
      PlaceCategory.amusementPark => Icons.attractions_outlined,
      PlaceCategory.trek => Icons.hiking_outlined,
      PlaceCategory.beach => Icons.beach_access_outlined,
      PlaceCategory.shopping => Icons.shopping_bag_outlined,
      PlaceCategory.nature => Icons.park_outlined,
      PlaceCategory.other => Icons.category_outlined,
    };

String placeCategoryLabel(AppLocalizations l10n, PlaceCategory category) =>
    switch (category) {
      PlaceCategory.hotel => l10n.catHotel,
      PlaceCategory.restaurant => l10n.catRestaurant,
      PlaceCategory.coffeeShop => l10n.catCoffeeShop,
      PlaceCategory.bar => l10n.catBar,
      PlaceCategory.attraction => l10n.catAttraction,
      PlaceCategory.museum => l10n.catMuseum,
      PlaceCategory.amusementPark => l10n.catAmusementPark,
      PlaceCategory.trek => l10n.catTrek,
      PlaceCategory.beach => l10n.catBeach,
      // Reuses Expense's category strings where the word is identical —
      // one translation to maintain, not two.
      PlaceCategory.shopping => l10n.catShopping,
      PlaceCategory.nature => l10n.catNature,
      PlaceCategory.other => l10n.catOther,
    };

/// Under 1 km shows meters (no useful decimal at that scale); under 10 km
/// keeps one decimal of km precision; beyond that, whole km — mirrors how
/// map apps taper precision as distance grows. Shared with the Near By
/// results/detail views.
String formatPlaceDistance(AppLocalizations l10n, double km) {
  if (km < 1) return l10n.placeDistanceMetersAway((km * 1000).round());
  final label = km < 10 ? km.toStringAsFixed(1) : km.round().toString();
  return l10n.placeDistanceKmAway(label);
}

/// Wishlist row: white card, teal pin, faint check target on the right.
/// Visited row: recessed paper card, gray, visited date, tap check to undo.
class PlaceRowCard extends StatefulWidget {
  const PlaceRowCard({
    super.key,
    required this.place,
    this.tripName,
    this.distanceKm,
    this.dayNumber,
    this.onToggleVisited,
    this.onTap,
  });

  final Place place;
  final String? tripName;

  /// Distance from the device's current fix, in km — `null` whenever no
  /// fix is available or this place has no coordinates. Computed by the
  /// caller (which already watches `currentLocationProvider`) rather than
  /// read from global state here.
  final double? distanceKm;

  /// 1-based trip day this place is tagged for — `null` when untagged or
  /// the place has no trip. Computed by the caller (`Trip.dayNumber`)
  /// rather than read from global state here.
  final int? dayNumber;
  final VoidCallback? onToggleVisited;
  final VoidCallback? onTap;

  @override
  State<PlaceRowCard> createState() => _PlaceRowCardState();
}

class _PlaceRowCardState extends State<PlaceRowCard> {
  bool _summaryExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final place = widget.place;
    final visited = place.isVisited;

    final metaParts = <String>[
      if (place.city.isNotEmpty) place.city,
      if (place.country.isNotEmpty) place.country,
      if (widget.distanceKm case final km?) formatPlaceDistance(l10n, km),
      if (widget.dayNumber case final day?) l10n.nearbyDayNumber(day),
      if (visited && place.visitedAt != null)
        l10n.visitedOn(
          DateFormat('dd MMM yyyy', l10n.localeName).format(place.visitedAt!),
        )
      else if (widget.tripName != null)
        widget.tripName!,
    ];

    return PaperCard(
      recessed: visited,
      onTap: widget.onTap,
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: AppSpacing.md,
        end: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            visited ? Icons.check_circle_outline : Icons.place_outlined,
            size: 20,
            color: visited ? colors.inkMuted : colors.accent,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoDirectionText(
                  place.name,
                  style: AppTextStyles.body.copyWith(
                    color: visited ? colors.inkSecondary : colors.inkPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (metaParts.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  MonoText(metaParts.join(' · '), muted: true),
                ],
                if (place.hasSummary) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _SummaryReveal(
                    summary: place.summary!,
                    expanded: _summaryExpanded,
                    onToggle: () =>
                        setState(() => _summaryExpanded = !_summaryExpanded),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            // M4.4 — a quiet 250ms cross-fade on tap, not a springy pop;
            // keyed on `visited` so AnimatedSwitcher treats the two states
            // as genuinely different children instead of tweening a shape.
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: Icon(
                visited ? Icons.check_circle : Icons.check_circle_outline,
                key: ValueKey(visited),
                size: 20,
                color: visited ? colors.inkMuted : colors.hairline,
              ),
            ),
            tooltip: visited ? l10n.placeUnvisit : l10n.placeMarkVisited,
            onPressed: widget.onToggleVisited,
          ),
        ],
      ),
    );
  }
}

/// The card's summary starts collapsed — a one-line mono toggle, matching
/// the metadata row above it — and expands in place to the full paragraph.
/// A nested [InkWell] (not the card's own `onTap`) so tapping it never
/// falls through to "open place actions".
class _SummaryReveal extends StatelessWidget {
  const _SummaryReveal({
    required this.summary,
    required this.expanded,
    required this.onToggle,
  });

  final String summary;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MonoText(
                    expanded ? l10n.placeSummaryHide : l10n.placeSummaryShow,
                    color: colors.accent,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.expand_more,
                      size: 16,
                      color: colors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: AlignmentDirectional.topStart,
            // Collapsed renders no Text at all (not just a hidden one) —
            // the point of "initially hidden" is that it isn't in the
            // tree, not merely invisible.
            child: expanded
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: AppSpacing.xs,
                    ),
                    child: AutoDirectionText(
                      summary,
                      style: AppTextStyles.body
                          .copyWith(color: colors.inkSecondary),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
      ],
    );
  }
}

/// M4.4 — a place row settling into its section: quiet 250ms fade + rise,
/// nothing springy. `want`/`been` are separate widget subtrees (two
/// sections, not one reorderable list), so a status flip can't "fly" a row
/// across the screen without adopting AnimatedList; this softens the
/// jump-cut at the moment a row lands in its new section instead. Keyed by
/// [placeId] so Flutter treats a status flip as a fresh landing, not a
/// tween of whatever row used to sit at that position.
class RowSettleAnimation extends StatelessWidget {
  const RowSettleAnimation({
    super.key,
    required this.placeId,
    required this.child,
  });

  final String placeId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(placeId),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 6),
          child: child,
        ),
      ),
    );
  }
}
