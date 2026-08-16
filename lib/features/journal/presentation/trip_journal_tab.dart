import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_chrome.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/domain/trip.dart';
import '../domain/journal_entry.dart';
import 'journal_entry_form_sheet.dart';
import 'journal_entry_presentation_sheet.dart';
import 'journal_globe.dart';
import 'journal_map_view.dart';
import 'journal_providers.dart';
import 'journal_widgets.dart';

/// Journal tab inside a trip's detail screen: a globe of this trip's
/// logged entries with the stats line, add-entry, and map-toggle actions
/// floating directly on it (no separate header bar — the globe/map fills
/// the whole tab), and the gallery timeline floating over its bottom edge
/// in globe mode. Holds [_selectedEntryId] as the coordinator between the
/// globe and the gallery — tapping either one's representation of an
/// entry focuses the other on it (design spec: bidirectional globe<->
/// gallery sync).
class TripJournalTab extends ConsumerStatefulWidget {
  const TripJournalTab({
    super.key,
    required this.trip,
    this.renderGlobe = true,
    this.renderMap = true,
  });

  final Trip trip;

  /// False in widget tests: the globe needs a GPU shader surface, same
  /// reasoning as JournalGlobe's own `renderGlobe` seam.
  final bool renderGlobe;

  /// False in widget tests: Google Maps needs a platform view, same
  /// reasoning as JournalMapView's own `renderMap` seam.
  final bool renderMap;

  @override
  ConsumerState<TripJournalTab> createState() => _TripJournalTabState();
}

class _TripJournalTabState extends ConsumerState<TripJournalTab> {
  String? _selectedEntryId;
  String? _liveFollowEntryId;

  static const _galleryStripHeight = 190.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncEntries = ref.watch(tripJournalProvider(widget.trip.id));
    final entries = asyncEntries.valueOrNull ?? const <JournalEntry>[];
    final visitedPlaces = ref.watch(tripVisitedPlacesProvider(widget.trip.id));
    final showMap = ref.watch(journalMapModeProvider);

    if (asyncEntries.hasValue && entries.isEmpty) {
      return EmptyState(
        icon: Icons.auto_stories_outlined,
        title: l10n.journalEmptyTitle,
        body: l10n.journalEmptyBody,
        ctaLabel: l10n.journalAddEntryCta,
        onCta: () => showJournalEntryFormSheet(context, tripId: widget.trip.id),
      );
    }

    // The globe/map fills the entire tab — no header bar splitting off
    // its own slice, and (in globe mode) no fixed 70/30 split pushing it
    // up to make room for the gallery below. Everything else floats on
    // top of it directly, Polarsteps-style: stats/actions in the top
    // corners, the gallery strip hovering over the bottom edge.
    return Stack(
      children: [
        // The globe owns this area — no ancestor scrollable wraps it, so
        // every pan/tap on it drives the globe, never a parent scroll.
        Positioned.fill(
          child: showMap
              ? JournalMapView(entries: entries, renderMap: widget.renderMap)
              : JournalGlobe(
                  entries: entries,
                  selectedEntryId: _selectedEntryId,
                  liveFollowEntryId: _liveFollowEntryId,
                  onEntryTap: (entry) =>
                      setState(() => _selectedEntryId = entry.id),
                  onClusterTap: (clusterEntries) {
                    setState(() => _selectedEntryId = clusterEntries.first.id);
                    showJournalEntryPresentationSheet(
                      context,
                      tripId: widget.trip.id,
                      entries: clusterEntries,
                      initialIndex: 0,
                      onPageChanged: (index) => setState(
                        () => _selectedEntryId = clusterEntries[index].id,
                      ),
                    );
                  },
                  renderGlobe: widget.renderGlobe,
                ),
        ),
        // Smooths the hard cut where the TabBar above hands off to the
        // globe/map's own busy, edge-to-edge imagery. Unlike
        // _GalleryOverlay below (deliberately out of scope for this
        // branch, still theme-aware colors.inkPrimary), _TopEdgeScrim
        // uses fixed AppColors.dark tokens — see its own class doc
        // comment for why. IgnorePointer: purely decorative, must never
        // intercept the globe's own drag/tap.
        const PositionedDirectional(
          top: 0,
          start: 0,
          end: 0,
          child: IgnorePointer(child: _TopEdgeScrim()),
        ),
        PositionedDirectional(
          top: 0,
          start: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: _GlassPill(
                child: MonoText(
                  l10n.journalStatsLine(entries.length, visitedPlaces.length),
                  color: AppColors.dark.inkPrimary,
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 0,
          end: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GlassIconButton(
                    icon: Icons.add,
                    tooltip: l10n.journalAddEntryCta,
                    onPressed: () => showJournalEntryFormSheet(
                      context,
                      tripId: widget.trip.id,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _GlassIconButton(
                    icon: showMap ? Icons.timeline : Icons.map_outlined,
                    tooltip: showMap ? l10n.listViewToggle : l10n.mapViewToggle,
                    onPressed: () => ref
                        .read(journalMapModeProvider.notifier)
                        .update((v) => !v),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!showMap)
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: _GalleryOverlay(
              height: _galleryStripHeight,
              child: JournalGalleryTimeline(
                entries: entries,
                selectedEntryId: _selectedEntryId,
                onTapDay: (dayEntries, tappedIndex) {
                  setState(
                    () => _selectedEntryId = dayEntries[tappedIndex].id,
                  );
                  showJournalEntryPresentationSheet(
                    context,
                    tripId: widget.trip.id,
                    entries: dayEntries,
                    initialIndex: tappedIndex,
                    onPageChanged: (index) => setState(
                      () => _selectedEntryId = dayEntries[index].id,
                    ),
                  );
                },
                onCenteredDayChanged: (dayEntries) => setState(
                  () => _liveFollowEntryId = dayEntries.first.id,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Backdrop for the gallery strip when it floats over the globe — a
/// bottom-anchored gradient so the strip's hairline day-track and card
/// borders stay legible over the globe's own busy, variable-brightness
/// texture, matching the same colors.inkPrimary-alpha-gradient convention
/// already used behind on-photo captions elsewhere in this feature.
class _GalleryOverlay extends StatelessWidget {
  const _GalleryOverlay({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.inkPrimary.withValues(alpha: 0),
                    colors.inkPrimary.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// A short fade at the very top of the globe/map, smoothing the hairline
/// seam against the TabBar above — fixed `AppColors.dark.paper`-based
/// gradient (not theme-aware `colors.inkPrimary`), same reasoning as
/// [_GlassPill]: this sits directly over the globe/map's own
/// unpredictable imagery, so the scrim must read as "quiet dark" in both
/// app themes, matching TripCard's and TripDetailScreen's cover-scrim
/// convention.
class _TopEdgeScrim extends StatelessWidget {
  const _TopEdgeScrim();

  static const _height = 28.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.dark.paper.withValues(alpha: 0.22),
            AppColors.dark.paper.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// A small translucent glass pill — the on-glass equivalent of
/// SectionLabel for content that floats directly over the globe/map.
/// Fixed `AppColors.dark.surface` tint (not theme-aware `colors.surface`):
/// this chrome sits directly over the globe/map's own unpredictable
/// imagery with no guaranteed-dark scrim behind it (unlike
/// TripDetailScreen's cover hero, which has one) — a theme-aware fill
/// would turn near-white in dark app-theme and read as a bright blob
/// instead of a quiet dark tint. Mirrors TripDetailScreen's own topbar
/// GlassChrome usage (trip_detail_screen.dart), the same "floating chrome
/// over unpredictable cover art" position.
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassChrome(
      borderRadius: BorderRadius.circular(AppShape.pillRadius),
      tint: AppColors.dark.surface,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm + 4,
          vertical: AppSpacing.xs,
        ),
        child: child,
      ),
    );
  }
}

/// A circular glass icon button on the same fixed-dark backdrop as
/// [_GlassPill] — the add-entry and map/list-toggle actions, floating on
/// the globe itself. See [_GlassPill]'s doc comment for why the tint is
/// fixed rather than theme-aware.
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// The visible Material/CircleBorder size — the icon button's
  /// `minimumSize`.
  static const _visibleSize = 36.0;

  /// Material 3's `IconButton` occupies a padded 48x48 tap-target box by
  /// default (this app sets no `tapTargetSize`/`visualDensity` override),
  /// even though its own visible Material/CircleBorder stays
  /// [_visibleSize]. [GlassChrome] sizes itself to its child's actual
  /// layout box — not the visible Material inside it — so the radius
  /// below must be half of THIS size to paint a true circle instead of a
  /// rounded-square "squircle" on a bigger box. This also happens to meet
  /// the 48dp minimum touch-target accessibility guideline.
  static const _tapTargetSize = 48.0;

  @override
  Widget build(BuildContext context) {
    return GlassChrome(
      borderRadius: BorderRadius.circular(_tapTargetSize / 2),
      tint: AppColors.dark.surface,
      child: IconButton(
        icon: Icon(icon, color: AppColors.dark.inkPrimary, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
          minimumSize: const Size(_visibleSize, _visibleSize),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
