import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/journal_entry.dart';
import 'journal_entry_form_sheet.dart';
import 'journal_photo_viewer.dart';
import 'journal_providers.dart';

/// Read-only presentation view for one day's journal entries, reached by
/// tapping a gallery card or a globe dot. Editing and deleting are no
/// longer the default tap action (design: "tap = view, edit is
/// explicit") — both live behind each page's overflow menu instead.
///
/// [entries] is always that day's full entry list (length 1 for a
/// single-entry day); [initialIndex] is which one to open on. Swiping
/// between entries reports the new index via [onPageChanged] so the
/// caller (TripJournalTab) can keep the globe/gallery selection in sync
/// with whichever entry is currently on screen.
Future<void> showJournalEntryPresentationSheet(
  BuildContext context, {
  required String tripId,
  required List<JournalEntry> entries,
  required int initialIndex,
  required void Function(int index) onPageChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _JournalEntryPresentationView(
      tripId: tripId,
      entries: entries,
      initialIndex: initialIndex,
      onPageChanged: onPageChanged,
    ),
  );
}

class _JournalEntryPresentationView extends ConsumerStatefulWidget {
  const _JournalEntryPresentationView({
    required this.tripId,
    required this.entries,
    required this.initialIndex,
    required this.onPageChanged,
  });

  final String tripId;
  final List<JournalEntry> entries;
  final int initialIndex;
  final void Function(int index) onPageChanged;

  @override
  ConsumerState<_JournalEntryPresentationView> createState() =>
      _JournalEntryPresentationViewState();
}

class _JournalEntryPresentationViewState
    extends ConsumerState<_JournalEntryPresentationView> {
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final currentEntry = widget.entries[_currentPage];
    final screenHeight = MediaQuery.of(context).size.height;
    final targetHeight = screenHeight * (currentEntry.hasPhotos ? 0.7 : 0.4);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: targetHeight,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                      widget.onPageChanged(index);
                    },
                    children: [
                      for (var i = 0; i < widget.entries.length; i++)
                        _JournalEntryPresentationPage(
                          entry: widget.entries[i],
                          onOverscrollNext: () {
                            if (i < widget.entries.length - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                          onOverscrollPrevious: () {
                            if (i > 0) {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                        ),
                    ],
                  ),
                  // Persistent header overlay — stays in one fixed position
                  // across every swipe (design spec: "keeps the header from
                  // jumping around while swiping between a photo entry and
                  // a stub entry in the same day"), styled by whichever
                  // entry is currently showing.
                  PositionedDirectional(
                    top: 8,
                    start: 0,
                    end: 0,
                    child: Center(
                      child: _handle(
                        currentEntry.hasPhotos
                            ? colors.surface.withValues(alpha: 0.85)
                            : colors.hairline,
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: currentEntry.hasPhotos ? 2 : 4,
                    end: 2,
                    child: _menu(
                      l10n,
                      hasPhoto: currentEntry.hasPhotos,
                      deleteColor: colors.error,
                      onEdit: () => _handleEdit(currentEntry),
                      onDelete: () => _handleDelete(currentEntry),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.entries.length > 1)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.entries.length; i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsetsDirectional.symmetric(
                          horizontal: 3,
                        ),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _currentPage
                              ? colors.accent
                              : colors.hairline,
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

  void _handleEdit(JournalEntry entry) {
    Navigator.of(context).pop();
    showJournalEntryFormSheet(context, tripId: widget.tripId, existing: entry);
  }

  Future<void> _handleDelete(JournalEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.journalDeleteEntryTitle),
        content: Text(l10n.journalDeleteEntryBody),
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
      await ref.read(journalRepositoryProvider).deleteEntry(entry.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _handle(Color color) => Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _menu(
    AppLocalizations l10n, {
    required bool hasPhoto,
    required Color deleteColor,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final colors = context.colors;
    final button = PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: hasPhoto ? colors.surface : colors.inkMuted,
        size: 20,
      ),
      padding: EdgeInsets.zero,
      splashRadius: 18,
      onSelected: (action) {
        if (action == 'edit') {
          onEdit();
        } else if (action == 'delete') {
          onDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'edit', child: Text(l10n.menuEdit)),
        PopupMenuItem(
          value: 'delete',
          child: Text(l10n.menuDelete, style: TextStyle(color: deleteColor)),
        ),
      ],
    );
    if (!hasPhoto) return button;
    // Softer, tighter backdrop — a low-alpha tint that reads as seamless
    // glass rather than a conspicuous solid disc, sized to the button's
    // own (now-reduced) footprint via SizedBox rather than the larger
    // default Material tap-target circle.
    return SizedBox(
      width: 36,
      height: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.inkPrimary.withValues(alpha: 0.32),
        ),
        child: button,
      ),
    );
  }
}

class _JournalEntryPresentationPage extends StatefulWidget {
  const _JournalEntryPresentationPage({
    required this.entry,
    required this.onOverscrollNext,
    required this.onOverscrollPrevious,
  });

  final JournalEntry entry;

  /// Called when the user keeps swiping past this entry's last photo —
  /// hands the gesture off to the outer (entry-to-entry) PageView, so
  /// swiping "past the end" of a photo carousel moves to the next
  /// entry instead of just bouncing.
  final VoidCallback onOverscrollNext;

  /// Same as above, for swiping past the first photo.
  final VoidCallback onOverscrollPrevious;

  @override
  State<_JournalEntryPresentationPage> createState() =>
      _JournalEntryPresentationPageState();
}

class _JournalEntryPresentationPageState
    extends State<_JournalEntryPresentationPage> {
  late final PageController _photoController;
  int _currentPhoto = 0;

  /// Latches after handing a boundary overscroll off to the outer
  /// (entry-to-entry) PageView. ClampingScrollPhysics re-dispatches an
  /// OverscrollNotification on every pointer move while pinned, and the
  /// outer nextPage() is itself a 300ms animation — without this, a slow
  /// drag would advance two entries instead of one. Cleared when the
  /// inner carousel reports a real page change or the scroll ends.
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    _photoController = PageController();
  }

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final entry = widget.entry;
    final placeName = entry.placeName;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Proportional, not a fixed pixel cap: on a real phone the sheet
        // is far taller than a test viewport, and a fixed 260px left the
        // photo under half the sheet instead of dominating it.
        final carouselHeight = entry.hasPhotos
            ? math.min(
                constraints.maxHeight * 0.62,
                math.max(0.0, constraints.maxHeight - 100),
              )
            : 0.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            entry.hasPhotos
                ? _photoCarousel(colors, carouselHeight)
                : const SizedBox(height: 40),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MonoText(
                      DateFormat('d MMMM yyyy · HH:mm').format(entry.loggedAt),
                    ),
                    if (placeName != null && placeName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        placeName,
                        style: AppTextStyles.title
                            .copyWith(color: colors.inkPrimary),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      entry.summary.isEmpty
                          ? l10n.journalUntitledEntry
                          : entry.summary,
                      style: AppTextStyles.body.copyWith(
                        color: entry.summary.isEmpty
                            ? colors.inkMuted
                            : colors.inkPrimary,
                        fontStyle: entry.summary.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _photoCarousel(AppColors colors, double height) {
    final photos = widget.entry.photos;
    return SizedBox(
      height: height,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is OverscrollNotification && !_handedOff) {
            if (notification.overscroll > 0 &&
                _currentPhoto == photos.length - 1) {
              _handedOff = true;
              widget.onOverscrollNext();
            } else if (notification.overscroll < 0 && _currentPhoto == 0) {
              _handedOff = true;
              widget.onOverscrollPrevious();
            }
          } else if (notification is ScrollEndNotification) {
            _handedOff = false;
          }
          return false;
        },
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: PageView(
                controller: _photoController,
                onPageChanged: (i) => setState(() {
                  _currentPhoto = i;
                  _handedOff = false;
                }),
                children: [
                  for (var i = 0; i < photos.length; i++)
                    GestureDetector(
                      onTap: () => showJournalPhotoViewer(
                        context,
                        photos: photos,
                        initialIndex: i,
                        onPageChanged: (newIndex) {
                          if (mounted && _photoController.hasClients) {
                            _photoController.jumpToPage(newIndex);
                          }
                        },
                      ),
                      child: Image.file(
                        File(photos[i].filePath),
                        width: double.infinity,
                        height: height,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: colors.paper),
                      ),
                    ),
                ],
              ),
            ),
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.inkPrimary.withValues(alpha: 0),
                      colors.inkPrimary.withValues(alpha: 0.4),
                    ],
                  ),
                ),
              ),
            ),
            if (photos.length > 1)
              PositionedDirectional(
                bottom: 10,
                start: 0,
                end: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < photos.length; i++)
                      Container(
                        key: ValueKey('photo-dot-$i'),
                        width: 6,
                        height: 6,
                        margin: const EdgeInsetsDirectional.symmetric(
                          horizontal: 3,
                        ),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _currentPhoto
                              ? colors.surface
                              : colors.surface.withValues(alpha: 0.5),
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
