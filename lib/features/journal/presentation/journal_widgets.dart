import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../core/widgets/section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/journal_entry.dart';
import '../domain/journal_entry_queries.dart';

/// A compact card for the horizontal entry gallery below the globe (design
/// reference: Wanderlog's journal filmstrip) — photo (or a placeholder)
/// on top, date + summary below. No existing photo/thumbnail precedent
/// elsewhere in the codebase — designed fresh on the app's card/hairline
/// conventions.
class JournalGalleryCard extends StatelessWidget {
  const JournalGalleryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onDelete,
  });

  final JournalEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  static const width = 148.0;
  static const photoHeight = 84.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: width,
      child: PaperCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            // The card has a natural (photo + text) size. FittedBox only
            // ever shrinks (never grows) to fit whatever the gallery strip
            // actually gives it — a plain Column would instead throw a
            // render overflow during a transient squeeze (e.g. a keyboard
            // animating over the tab shrinks the 30% strip below the
            // card's natural height).
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.topStart,
              child: SizedBox(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppShape.radius - 1),
                      ),
                      child: entry.hasPhotos
                          ? Image.file(
                              File(entry.photos.first.filePath),
                              width: width,
                              height: photoHeight,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  placeholder(colors),
                            )
                          : placeholder(colors),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MonoText(
                            DateFormat('dd MMM').format(entry.loggedAt),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.summary.isEmpty
                                ? AppLocalizations.of(context)!
                                    .journalUntitledEntry
                                : entry.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body.copyWith(
                              fontSize: 12,
                              color: colors.inkPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onDelete != null)
              PositionedDirectional(
                top: 4,
                end: 4,
                child: Material(
                  color: colors.surface.withValues(alpha: 0.85),
                  shape: const CircleBorder(),
                  child: IconButton(
                    iconSize: 14,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.close, color: colors.inkMuted),
                    onPressed: onDelete,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget placeholder(AppColors colors) => Container(
        width: width,
        height: photoHeight,
        color: colors.paper,
        alignment: Alignment.center,
        child: Icon(Icons.edit_note, color: colors.inkMuted),
      );
}

/// Horizontal, day-grouped timeline for the strip below the globe: a
/// hairline track with one dot per calendar day, each day's card hanging
/// below it on a short stem. A day with more than one entry renders as a
/// stacked-photo card with a count badge instead of [JournalGalleryCard]
/// directly; tapping it opens [showJournalDayEntriesSheet].
class JournalGalleryTimeline extends StatelessWidget {
  const JournalGalleryTimeline({
    super.key,
    required this.entries,
    required this.onEdit,
    required this.onDelete,
  });

  final List<JournalEntry> entries;
  final void Function(JournalEntry entry) onEdit;
  final void Function(JournalEntry entry) onDelete;

  static const _dotSize = 11.0;
  static const _stemHeight = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final days = groupEntriesByDay(entries);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            end: 0,
            top: _dotSize / 2 - 1,
            child: Container(height: 2, color: colors.hairline),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: _dotSize / 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final day in days)
                  Padding(
                    padding:
                        const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                    child: _DaySlot(
                      day: day,
                      colors: colors,
                      onEdit: onEdit,
                      onDelete: onDelete,
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

class _DaySlot extends StatelessWidget {
  const _DaySlot({
    required this.day,
    required this.colors,
    required this.onEdit,
    required this.onDelete,
  });

  final List<JournalEntry> day;
  final AppColors colors;
  final void Function(JournalEntry entry) onEdit;
  final void Function(JournalEntry entry) onDelete;

  @override
  Widget build(BuildContext context) {
    final first = day.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: JournalGalleryTimeline._dotSize,
          height: JournalGalleryTimeline._dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.accent,
            border: Border.all(color: colors.paper, width: 2),
          ),
        ),
        Container(
          width: 1,
          height: JournalGalleryTimeline._stemHeight,
          color: colors.hairline,
        ),
        // Flexible, not a bare child: a plain Column gives non-flex
        // children an unbounded main-axis constraint, which would let the
        // card's internal FittedBox report its natural (unshrunk) size and
        // overflow the slot whenever the strip is shorter than that. This
        // hands the card whatever height remains after the dot and stem,
        // so FittedBox has a real bound to scale down against.
        Flexible(
          child: day.length == 1
              ? JournalGalleryCard(
                  entry: first,
                  onTap: () => onEdit(first),
                  onDelete: () => onDelete(first),
                )
              : _GroupedGalleryCard(
                  day: day,
                  onOpenDay: () => showJournalDayEntriesSheet(
                    context,
                    entries: day,
                    onEdit: onEdit,
                  ),
                ),
        ),
      ],
    );
  }
}

class _GroupedGalleryCard extends StatelessWidget {
  const _GroupedGalleryCard({required this.day, required this.onOpenDay});

  final List<JournalEntry> day;
  final VoidCallback onOpenDay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final first = day.first;
    final photoEntry = day.firstWhere((e) => e.hasPhotos, orElse: () => first);

    return SizedBox(
      width: JournalGalleryCard.width,
      child: PaperCard(
        onTap: onOpenDay,
        padding: EdgeInsets.zero,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(
            width: JournalGalleryCard.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Extra ~6px of top space for the peeking card-edge slivers
                // below — accounted for in _DaySlot's Flexible sizing so it
                // doesn't reintroduce the overflow Task 7 fixed.
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 6),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Stacked-photo effect: two thin "card edge" slivers
                      // peeking out above/behind the top photo, evoking a
                      // fanned stack of photos (design spec §3 Gallery).
                      PositionedDirectional(
                        top: -6,
                        start: 10,
                        end: 10,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border.all(
                              color: colors.hairline,
                              width: AppShape.hairlineWidth,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        top: -3,
                        start: 5,
                        end: 5,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border.all(
                              color: colors.hairline,
                              width: AppShape.hairlineWidth,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppShape.radius - 1),
                        ),
                        child: photoEntry.hasPhotos
                            ? Image.file(
                                File(photoEntry.photos.first.filePath),
                                width: JournalGalleryCard.width,
                                height: JournalGalleryCard.photoHeight,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    JournalGalleryCard.placeholder(colors),
                              )
                            : JournalGalleryCard.placeholder(colors),
                      ),
                      PositionedDirectional(
                        top: 6,
                        end: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.inkPrimary.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: MonoText(
                              '${day.length}',
                              color: colors.surface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MonoText(DateFormat('dd MMM').format(first.loggedAt)),
                      const SizedBox(height: 2),
                      Text(
                        first.summary.isEmpty
                            ? AppLocalizations.of(context)!.journalUntitledEntry
                            : first.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 12,
                          color: colors.inkPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing one day's entries — reached by tapping a
/// multi-entry [JournalGalleryTimeline] card. Tapping a row closes the
/// sheet and calls [onEdit] for that entry.
Future<void> showJournalDayEntriesSheet(
  BuildContext context, {
  required List<JournalEntry> entries,
  required void Function(JournalEntry entry) onEdit,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _JournalDayEntriesSheet(entries: entries, onEdit: onEdit),
  );
}

class _JournalDayEntriesSheet extends StatelessWidget {
  const _JournalDayEntriesSheet({required this.entries, required this.onEdit});

  final List<JournalEntry> entries;
  final void Function(JournalEntry entry) onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final day = entries.first.loggedAt;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: SectionLabel(
              l10n.journalDayEntriesTitle(
                entries.length,
                DateFormat('d MMMM').format(day),
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final entry in entries)
                  ListTile(
                    leading: entry.hasPhotos
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(
                              File(entry.photos.first.filePath),
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _dayRowPlaceholder(colors),
                            ),
                          )
                        : _dayRowPlaceholder(colors),
                    title: Text(
                      entry.summary.isEmpty
                          ? l10n.journalUntitledEntry
                          : entry.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: MonoText(
                      DateFormat('HH:mm').format(entry.loggedAt),
                      muted: true,
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      onEdit(entry);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _dayRowPlaceholder(AppColors colors) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colors.paper,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.hairline),
        ),
        child: Icon(Icons.edit_note, color: colors.inkMuted),
      );
}
