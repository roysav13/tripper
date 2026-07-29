import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/place.dart';

/// Wishlist row: white card, teal pin, faint check target on the right.
/// Visited row: recessed paper card, gray, visited date, tap check to undo.
class PlaceRowCard extends StatelessWidget {
  const PlaceRowCard({
    super.key,
    required this.place,
    this.tripName,
    this.onToggleVisited,
    this.onTap,
  });

  final Place place;
  final String? tripName;
  final VoidCallback? onToggleVisited;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final visited = place.isVisited;

    final metaParts = <String>[
      if (place.city.isNotEmpty) place.city,
      if (place.country.isNotEmpty) place.country,
      if (visited && place.visitedAt != null)
        l10n.visitedOn(DateFormat('dd MMM yyyy').format(place.visitedAt!))
      else if (tripName != null)
        tripName!,
    ];

    return PaperCard(
      recessed: visited,
      onTap: onTap,
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: AppSpacing.md,
        end: AppSpacing.sm,
      ),
      child: Row(
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
                Text(
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
            onPressed: onToggleVisited,
          ),
        ],
      ),
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

/// Trophy-case stats header: mono numerals, quiet labels.
class PlaceStatsHeader extends StatelessWidget {
  const PlaceStatsHeader({
    super.key,
    required this.countries,
    required this.visited,
    required this.days,
  });

  final int countries;
  final int visited;

  /// Days actually travelled (M5.6) — past and in-progress only.
  final int days;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final divider = Container(width: 0.5, height: 36, color: colors.hairline);
    return PaperCard(
      child: Row(
        children: [
          Expanded(
            child: _stat(context, '$countries', l10n.statsCountries),
          ),
          divider,
          Expanded(
            child: _stat(context, '$visited', l10n.statsPlacesVisited),
          ),
          divider,
          Expanded(
            child: _stat(context, '$days', l10n.statsDaysTraveled),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final colors = context.colors;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: colors.inkPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: AppTextStyles.sectionLabel.copyWith(color: colors.inkMuted),
        ),
      ],
    );
  }
}
