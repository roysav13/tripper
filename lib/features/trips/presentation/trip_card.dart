import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/ticket_card.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/trip.dart';

/// All date formatting for trips goes through here (locale = one-file change).
abstract final class TripDateFormatter {
  static String single(DateTime d) => DateFormat('dd MMM').format(d);

  static String range(DateTime start, DateTime end) =>
      '${single(start)} – ${single(end)}';

  /// "16 JUL – 27 JUL" · "From 16 Jul" (open-ended) · "Dates TBD" (planned).
  /// MonoText uppercases downstream.
  static String line(AppLocalizations l10n, Trip trip) {
    final start = trip.startDate;
    if (start == null) return l10n.datesTbd;
    final end = trip.endDate;
    if (end == null) return l10n.fromDate(single(start));
    return range(start, end);
  }
}

/// Day chip text for an active trip: "Day 4 of 12", or "Day 4" open-ended.
String activeDayLabel(AppLocalizations l10n, Trip trip, DateTime today) {
  final day = trip.dayNumber(today)!;
  final length = trip.lengthInDays;
  return length == null
      ? l10n.tripDayOpen(day)
      : l10n.tripDayCount(day, length);
}

/// A past trip's identity color recedes toward paper instead of standing
/// out — mirrors the old `PaperCard(recessed: true)` treatment, now applied
/// to [TicketCard]'s accent instead of swapping the surface tone. Shared
/// between [TripCard] and the trip detail header so a trip reads
/// consistently faded everywhere it appears once it's over.
Color tripCardAccent(AppColors colors, Trip trip, TripStatus status) {
  final base = colors.tripAccent(trip.colorTag);
  if (status != TripStatus.past) return base;
  return Color.lerp(base, colors.paper, 0.6)!;
}

class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.status,
    required this.today,
    this.onTap,
  });

  final Trip trip;
  final TripStatus status;
  final DateTime today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final isPast = status == TripStatus.past;
    final ink = isPast ? colors.inkSecondary : colors.inkPrimary;
    // The card is one atomic tappable unit for accessibility — see
    // TicketCard's class doc for why this can't be left to automatic
    // semantics merging once this many paint layers sit in between.
    final dateAndPlaces =
        '${TripDateFormatter.line(l10n, trip)}. ${trip.destinations.join(', ')}';
    final semanticLabel = status == TripStatus.active
        ? '${trip.name}. $dateAndPlaces. ${activeDayLabel(l10n, trip, today)}'
        : '${trip.name}. $dateAndPlaces';

    return TicketCard(
      accentColor: tripCardAccent(colors, trip, status),
      onTap: onTap,
      semanticLabel: semanticLabel,
      stub: _TripStub(trip: trip, status: status, today: today, l10n: l10n),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Shares a tag with the AppBar title in TripDetailScreen —
          // M4.4's "Hero the trip name list→detail", now flying into the
          // M7 hero header instead of a small AppBar title. Both routes
          // sit in the same shell-branch Navigator, so this flies on the
          // default push transition with no extra wiring.
          Hero(
            tag: 'trip-name-${trip.id}',
            child: Material(
              type: MaterialType.transparency,
              child: Text(
                trip.name,
                style: AppTextStyles.title.copyWith(fontSize: 18, color: ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          MonoText(
            '${TripDateFormatter.line(l10n, trip)}'
            ' · ${trip.destinations.join(' → ')}',
            muted: isPast,
          ),
        ],
      ),
    );
  }
}

/// The colored stub's content: a big day-count for an active trip, a
/// status icon otherwise. Text/icon color comes from [TicketCard]'s
/// ambient `DefaultTextStyle`/`IconTheme` (already contrast-resolved via
/// `AppColors.onColor`), so nothing here sets color explicitly.
class _TripStub extends StatelessWidget {
  const _TripStub({
    required this.trip,
    required this.status,
    required this.today,
    required this.l10n,
  });

  final Trip trip;
  final TripStatus status;
  final DateTime today;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (status == TripStatus.active) {
      final day = trip.dayNumber(today)!;
      final length = trip.lengthInDays;
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$day', style: AppTextStyles.statValue.copyWith(fontSize: 28)),
          if (length != null)
            Text(
              l10n.tripStubOfCount(length).toUpperCase(),
              style: AppTextStyles.sectionLabel.copyWith(letterSpacing: 0.6),
              maxLines: 1,
            ),
        ],
      );
    }
    final icon = switch (status) {
      TripStatus.active => Icons.today_outlined, // unreachable, see above
      TripStatus.upcoming => Icons.event_outlined,
      TripStatus.planned => Icons.explore_outlined,
      TripStatus.past => Icons.check_circle_outline,
    };
    return Icon(icon, size: 26);
  }
}
