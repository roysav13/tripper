import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/trip.dart';

/// All date formatting for trips goes through here (locale = one-file change).
abstract final class TripDateFormatter {
  static String single(DateTime d) => DateFormat('dd MMM', 'en_US').format(d);

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

    return PaperCard(
      recessed: isPast,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                // Shares a tag with the AppBar title in TripDetailScreen —
                // M4.4's "Hero the trip name list→detail". Both routes sit
                // in the same shell-branch Navigator, so this flies on the
                // default push transition with no extra wiring.
                child: Hero(
                  tag: 'trip-name-${trip.id}',
                  child: Material(
                    type: MaterialType.transparency,
                    child: Text(
                      trip.name,
                      style: AppTextStyles.title
                          .copyWith(fontSize: 17, color: ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              if (status == TripStatus.active) ...[
                const SizedBox(width: AppSpacing.sm),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(AppShape.radius),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    child: Text(
                      activeDayLabel(l10n, trip, today),
                      style: AppTextStyles.sectionLabel.copyWith(
                        color: colors.surface,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
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
