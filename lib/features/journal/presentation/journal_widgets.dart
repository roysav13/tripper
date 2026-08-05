import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/paper_card.dart';
import '../domain/journal_entry.dart';
import '../domain/journal_entry_queries.dart';

/// A compact card for the horizontal entry gallery below the globe —
/// photo (or a placeholder) on top, a thin date + place caption below.
/// Tapping opens the read-only presentation view (never edits directly —
/// design spec: "tap = view, edit is explicit"), so the card no longer
/// carries summary text or a delete action; both live in that view now.
class JournalGalleryCard extends StatelessWidget {
  const JournalGalleryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.selected = false,
  });

  final JournalEntry entry;
  final VoidCallback? onTap;

  /// True while this entry is the globe/gallery's shared selection —
  /// rendered as an accent-colored border in place of the usual hairline.
  final bool selected;

  static const width = 116.0;
  static const photoHeight = 88.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final placeName = entry.placeName;

    return SizedBox(
      width: width,
      child: PaperCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        borderColor: selected ? colors.accent : null,
        // The card has a natural (photo + caption) size. FittedBox only
        // ever shrinks (never grows) to fit whatever the gallery strip
        // actually gives it — a plain Column would instead throw a
        // render overflow during a transient squeeze (e.g. a keyboard
        // animating over the tab shrinks the strip below the card's
        // natural height).
        child: FittedBox(
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
                          errorBuilder: (_, __, ___) => placeholder(colors),
                        )
                      : placeholder(colors),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MonoText(DateFormat('dd MMM').format(entry.loggedAt)),
                      if (placeName != null && placeName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          placeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.accent,
                            fontWeight: FontWeight.w500,
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
/// directly. Tapping any day reports it via [onTapDay] (index 0 for a
/// grouped day — the compact card can't pick a specific entry, the
/// presentation view's swipe does that instead). [selectedEntryId] is
/// the globe/gallery's shared selection: the matching day's card gets an
/// accent border, and the strip auto-scrolls to bring it into view.
class JournalGalleryTimeline extends StatefulWidget {
  const JournalGalleryTimeline({
    super.key,
    required this.entries,
    required this.selectedEntryId,
    required this.onTapDay,
  });

  final List<JournalEntry> entries;
  final String? selectedEntryId;
  final void Function(List<JournalEntry> dayEntries, int tappedIndex) onTapDay;

  static const _dotSize = 11.0;
  static const _stemHeight = 22.0;

  @override
  State<JournalGalleryTimeline> createState() => _JournalGalleryTimelineState();
}

class _JournalGalleryTimelineState extends State<JournalGalleryTimeline> {
  /// Keyed by each day's first (earliest) entry id — stable across
  /// rebuilds as long as that entry stays the earliest one for its day,
  /// which is true unless entries are added/removed within the day.
  final _slotKeys = <String, GlobalKey>{};

  @override
  void didUpdateWidget(JournalGalleryTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedEntryId != null &&
        widget.selectedEntryId != oldWidget.selectedEntryId) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    final days = groupEntriesByDay(widget.entries);
    for (final day in days) {
      if (!day.any((e) => e.id == widget.selectedEntryId)) continue;
      final key = _slotKeys[day.first.id];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final renderContext = key?.currentContext;
        if (renderContext == null) return;
        Scrollable.ensureVisible(
          renderContext,
          duration: const Duration(milliseconds: 300),
          alignment: 0.5,
        );
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final days = groupEntriesByDay(widget.entries);
    final dayIds = {for (final day in days) day.first.id};
    _slotKeys.removeWhere((id, _) => !dayIds.contains(id));
    for (final day in days) {
      _slotKeys.putIfAbsent(day.first.id, GlobalKey.new);
    }

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
            top: JournalGalleryTimeline._dotSize / 2 - 1,
            child: Container(height: 2, color: colors.hairline),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: JournalGalleryTimeline._dotSize / 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final day in days)
                  Padding(
                    key: _slotKeys[day.first.id],
                    padding:
                        const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                    child: _DaySlot(
                      day: day,
                      colors: colors,
                      selected:
                          day.any((e) => e.id == widget.selectedEntryId),
                      onTap: () => widget.onTapDay(day, 0),
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
    required this.selected,
    required this.onTap,
  });

  final List<JournalEntry> day;
  final AppColors colors;
  final bool selected;
  final VoidCallback onTap;

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
              ? JournalGalleryCard(entry: first, onTap: onTap, selected: selected)
              : _GroupedGalleryCard(day: day, onTap: onTap, selected: selected),
        ),
      ],
    );
  }
}

class _GroupedGalleryCard extends StatelessWidget {
  const _GroupedGalleryCard({
    required this.day,
    required this.onTap,
    required this.selected,
  });

  final List<JournalEntry> day;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final first = day.first;
    final photoEntry = day.firstWhere((e) => e.hasPhotos, orElse: () => first);
    final placeName = first.placeName;

    return SizedBox(
      width: JournalGalleryCard.width,
      child: PaperCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        borderColor: selected ? colors.accent : null,
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
                // doesn't reintroduce a Column-overflow.
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 6),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Stacked-photo effect: two thin "card edge" slivers
                      // peeking out above/behind the top photo, evoking a
                      // fanned stack of photos.
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
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MonoText(DateFormat('dd MMM').format(first.loggedAt)),
                      if (placeName != null && placeName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          placeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.accent,
                            fontWeight: FontWeight.w500,
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
      ),
    );
  }
}

