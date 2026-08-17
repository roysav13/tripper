import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/generated_cover_gradient.dart';
import '../../../core/widgets/auto_direction_text.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/trip.dart';

/// All date formatting for trips goes through here (locale = one-file change).
abstract final class TripDateFormatter {
  static String single(DateTime d, AppLocalizations l10n) =>
      DateFormat('dd MMM', l10n.localeName).format(d);

  static String range(DateTime start, DateTime end, AppLocalizations l10n) =>
      '${single(start, l10n)} – ${single(end, l10n)}';

  /// "16 JUL – 27 JUL" · "From 16 Jul" (open-ended) · "Dates TBD" (planned).
  /// MonoText uppercases downstream.
  static String line(AppLocalizations l10n, Trip trip) {
    final start = trip.startDate;
    if (start == null) return l10n.datesTbd;
    final end = trip.endDate;
    if (end == null) return l10n.fromDate(single(start, l10n));
    return range(start, end, l10n);
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

  static const _coverHeight = 140.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final isPast = status == TripStatus.past;

    return PaperCard(
      recessed: isPast,
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppShape.radius),
            ),
            child: SizedBox(
              height: _coverHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Shares a tag with TripDetailScreen's cover hero. Both
                  // routes sit in the same shell-branch Navigator, so this
                  // flies on the default push transition with no extra
                  // wiring — same as the pre-existing trip-name Hero below,
                  // which is untouched. Kept as a sibling of that Hero
                  // (rather than wrapping it) because Flutter forbids a
                  // Hero being the descendant of another Hero.
                  Hero(
                    tag: 'trip-cover-${trip.id}',
                    child: _CoverBackground(trip: trip, colors: colors),
                  ),
                  // Text-on-photo scrim (component rule 6: every
                  // text-on-photo moment gets a scrim strong enough to
                  // hit WCAG AA).
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xBF12141C)],
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: AppSpacing.md,
                    end: AppSpacing.md,
                    bottom: AppSpacing.sm,
                    child: Row(
                      children: [
                        Expanded(
                          child: Hero(
                            tag: 'trip-name-${trip.id}',
                            child: Material(
                              type: MaterialType.transparency,
                              child: AutoDirectionText(
                                trip.name,
                                style: AppTextStyles.title.copyWith(
                                  fontSize: 17,
                                  color: AppColors.dark.inkPrimary,
                                ),
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
                              borderRadius:
                                  BorderRadius.circular(AppShape.radius),
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
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            child: MonoText(
              '${TripDateFormatter.line(l10n, trip)}'
              ' · ${trip.destinations.join(' → ')}',
              muted: isPast,
            ),
          ),
        ],
      ),
    );
  }
}

/// The cover image if the trip has one, else the deterministic gradient
/// fallback (component rule 2: gradients scoped to hero/cover art only —
/// this is that art).
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
