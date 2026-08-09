import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/paper_card.dart';
import '../domain/journal_entry.dart';
import '../domain/journal_entry_queries.dart';

/// A compact card for the horizontal entry gallery below the globe —
/// photo on top, a single-line date + place caption below. Tapping
/// opens the read-only presentation view (never edits directly), so the
/// card carries no summary text or delete action.
class JournalGalleryCard extends StatelessWidget {
  const JournalGalleryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.selected = false,
  });

  final JournalEntry entry;
  final VoidCallback? onTap;

  /// True while this entry is the globe/gallery's shared (tap-driven)
  /// selection — rendered as an accent-colored border in place of the
  /// usual hairline.
  final bool selected;

  static const width = 150.0;
  static const photoHeight = 130.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final placeName = entry.placeName;
    final hasPhoto = entry.hasPhotos;

    // The card has a natural (photo) size. Scaling it down to fit
    // whatever height the gallery strip actually gives it (e.g. a
    // keyboard animating over the tab, or simply a shorter screen) can't
    // use a plain FittedBox here: FittedBox always reports its OWN full
    // incoming width to its parent regardless of how much its child
    // actually shrank, which — combined with the scaled content aligning
    // to the top-start corner inside that still-full-width outer box —
    // left a visible dead-space wedge to the trailing side whenever the
    // strip forced a shrink. Computing the scale ourselves and sizing the
    // outer box to match keeps the card's painted footprint equal to
    // what's actually visible, in both directions, with no dead space.
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? (constraints.maxHeight / photoHeight).clamp(0.0, 1.0)
                : 1.0;
        return SizedBox(
          width: width * scale,
          height: photoHeight * scale,
          child: PaperCard(
            onTap: onTap,
            padding: EdgeInsets.zero,
            borderColor: selected ? colors.accent : null,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppShape.radius - 1),
                  child: SizedBox(
                    width: width,
                    height: photoHeight,
                    child: Stack(
                      children: [
                        hasPhoto
                            ? Image.file(
                                File(entry.photos.first.filePath),
                                width: width,
                                height: photoHeight,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    placeholder(colors),
                              )
                            : placeholder(colors),
                        // Bottom gradient scrim so the overlaid caption
                        // stays legible over a bright photo — no scrim
                        // on the placeholder case below, since there's
                        // nothing to darken against.
                        if (hasPhoto)
                          PositionedDirectional(
                            start: 0,
                            end: 0,
                            bottom: 0,
                            child: Container(
                              height: photoHeight * 0.6,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    colors.inkPrimary.withValues(alpha: 0),
                                    colors.inkPrimary.withValues(alpha: 0.85),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (entry.photos.length > 1)
                          PositionedDirectional(
                            top: 6,
                            end: 6,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color:
                                    colors.inkPrimary.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsetsDirectional.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                child: MonoText(
                                  '${entry.photos.length}',
                                  color: colors.surface,
                                ),
                              ),
                            ),
                          ),
                        PositionedDirectional(
                          start: 8,
                          end: 8,
                          bottom: 8,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MonoText(
                                DateFormat('dd MMM').format(entry.loggedAt),
                                color: hasPhoto
                                    ? colors.surface.withValues(alpha: 0.75)
                                    : colors.inkMuted,
                              ),
                              if (placeName != null &&
                                  placeName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  placeName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.title.copyWith(
                                    fontSize: 17,
                                    color: hasPhoto
                                        ? colors.surface
                                        : colors.inkPrimary,
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
            ),
          ),
        );
      },
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
    required this.onCenteredDayChanged,
  });

  final List<JournalEntry> entries;
  final String? selectedEntryId;
  final void Function(List<JournalEntry> dayEntries, int tappedIndex) onTapDay;

  /// Fired continuously as the strip scrolls, whenever the day-slot
  /// closest to the visible viewport's horizontal center changes —
  /// drives the globe's live-follow (JournalGlobe.liveFollowEntryId),
  /// separate from the tap-driven selection above.
  final void Function(List<JournalEntry> dayEntries) onCenteredDayChanged;

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
  final _scrollViewKey = GlobalKey();
  String? _lastCenteredDayId;

  /// True while [_scrollToSelected]'s `ensureVisible` animation is
  /// running. That programmatic scroll emits the same
  /// ScrollStart/ScrollUpdate notifications as a real drag, so without
  /// this latch a tap-driven scroll would report a (wrong, mid-animation)
  /// centered day up to live-follow and clobber the tap's own selection.
  bool _programmaticScroll = false;

  /// Bumped once per programmatic scroll. `ensureVisible`'s TickerFuture
  /// also completes when a later `animateTo` on the same ScrollPosition
  /// supersedes it, so a rapid second tap resolves the FIRST call's await
  /// early — without this, that stale completion would clear the latch
  /// while the second scroll is still in flight and reopen the very
  /// live-follow corruption window this latch exists to close. Only the
  /// most recent generation is allowed to clear the flag.
  int _scrollGeneration = 0;

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
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final renderContext = key?.currentContext;
        if (renderContext == null) return;
        final myGeneration = ++_scrollGeneration;
        _programmaticScroll = true;
        // try/finally, not a bare await: if ensureVisible ever completes
        // with an error (e.g. the target render context goes invalid
        // mid-animation) the latch would otherwise stay true forever and
        // silently disable live-follow reporting for good.
        try {
          await Scrollable.ensureVisible(
            renderContext,
            duration: const Duration(milliseconds: 300),
            alignment: 0.5,
          );
        } finally {
          if (myGeneration == _scrollGeneration) {
            _programmaticScroll = false;
          }
        }
      });
      return;
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_programmaticScroll) return false;
    if (notification is ScrollUpdateNotification ||
        notification is ScrollStartNotification) {
      _reportCenteredDay();
    }
    return false;
  }

  /// Finds whichever day-slot's horizontal center is closest to the
  /// scroll viewport's own horizontal center, and reports it via
  /// widget.onCenteredDayChanged — but only when it actually changes,
  /// not on every scroll pixel.
  void _reportCenteredDay() {
    final viewportBox =
        _scrollViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) return;
    final viewportCenterX =
        viewportBox.localToGlobal(Offset(viewportBox.size.width / 2, 0)).dx;

    final days = groupEntriesByDay(widget.entries);
    String? closestDayId;
    var closestDistance = double.infinity;
    for (final day in days) {
      final slotBox = _slotKeys[day.first.id]
          ?.currentContext
          ?.findRenderObject() as RenderBox?;
      if (slotBox == null || !slotBox.hasSize) continue;
      final slotCenterX =
          slotBox.localToGlobal(Offset(slotBox.size.width / 2, 0)).dx;
      final distance = (slotCenterX - viewportCenterX).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        closestDayId = day.first.id;
      }
    }
    if (closestDayId == null || closestDayId == _lastCenteredDayId) return;
    _lastCenteredDayId = closestDayId;
    final day = days.firstWhere((d) => d.first.id == closestDayId);
    widget.onCenteredDayChanged(day);
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

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: SingleChildScrollView(
        key: _scrollViewKey,
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
              ? JournalGalleryCard(
                  entry: first,
                  onTap: onTap,
                  selected: selected,
                )
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
    final hasPhoto = photoEntry.hasPhotos;

    // Same manual scale-and-resize approach as JournalGalleryCard, for
    // the same reason — a plain FittedBox always reports its full given
    // width to its parent regardless of how much its child actually
    // shrank, leaving dead space to the trailing side whenever the strip
    // forces a shrink. See that class's build() for the full rationale;
    // this mirrors it exactly so both card types keep reporting the same
    // natural (unscaled) height, which is what keeps them scaling down
    // in lockstep instead of one rendering visibly smaller than the other.
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? (constraints.maxHeight / JournalGalleryCard.photoHeight)
                    .clamp(0.0, 1.0)
                : 1.0;
        return SizedBox(
          width: JournalGalleryCard.width * scale,
          height: JournalGalleryCard.photoHeight * scale,
          child: PaperCard(
            onTap: onTap,
            padding: EdgeInsets.zero,
            borderColor: selected ? colors.accent : null,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: JournalGalleryCard.width,
                // Extra ~6px of top space for the peeking card-edge
                // slivers below — accounted for in _DaySlot's Flexible
                // sizing so it doesn't reintroduce a Column-overflow.
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(top: 6),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Stacked-photo effect: two thin "card edge" slivers
                      // peeking out above/behind the top photo, evoking a
                      // fanned stack of photos. Deliberately outside the
                      // ClipRRect below, same as before this redesign — they
                      // need to poke past the card's rounded bounds.
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
                        borderRadius:
                            BorderRadius.circular(AppShape.radius - 1),
                        child: SizedBox(
                          width: JournalGalleryCard.width,
                          // 6px shorter than JournalGalleryCard.photoHeight to
                          // offset this card's top: 6 padding above — keeps the
                          // grouped card's total natural height pixel-identical
                          // to the single-entry card's (both 130), so the
                          // shared FittedBox in _DaySlot doesn't scale one down
                          // more than the other.
                          height: JournalGalleryCard.photoHeight - 6,
                          child: Stack(
                            children: [
                              hasPhoto
                                  ? Image.file(
                                      File(photoEntry.photos.first.filePath),
                                      width: JournalGalleryCard.width,
                                      height:
                                          JournalGalleryCard.photoHeight - 6,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          JournalGalleryCard.placeholder(
                                        colors,
                                      ),
                                    )
                                  : JournalGalleryCard.placeholder(colors),
                              if (hasPhoto)
                                PositionedDirectional(
                                  start: 0,
                                  end: 0,
                                  bottom: 0,
                                  child: Container(
                                    height:
                                        (JournalGalleryCard.photoHeight - 6) *
                                            0.6,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          colors.inkPrimary
                                              .withValues(alpha: 0),
                                          colors.inkPrimary
                                              .withValues(alpha: 0.85),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              PositionedDirectional(
                                start: 8,
                                end: 8,
                                bottom: 8,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    MonoText(
                                      DateFormat('dd MMM')
                                          .format(first.loggedAt),
                                      color: hasPhoto
                                          ? colors.surface
                                              .withValues(alpha: 0.75)
                                          : colors.inkMuted,
                                    ),
                                    if (placeName != null &&
                                        placeName.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        placeName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.title.copyWith(
                                          fontSize: 17,
                                          color: hasPhoto
                                              ? colors.surface
                                              : colors.inkPrimary,
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
                      // Day-count badge stays outside the ClipRRect, same
                      // position as before this redesign — it's always shown
                      // here (unconditionally, unlike the photo-count badge
                      // above) since a grouped card is only ever built for
                      // day.length > 1.
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
              ),
            ),
          ),
        );
      },
    );
  }
}
