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

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
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
                          color: i == _currentPage ? colors.accent : colors.hairline,
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
      ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.inkPrimary.withValues(alpha: 0.55),
      ),
      child: button,
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

  static const _photoAreaHeight = 260.0;

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
        final carouselHeight = entry.hasPhotos
            ? math.min(
                _photoAreaHeight,
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
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: colors.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            placeName,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
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
      child: NotificationListener<OverscrollNotification>(
        onNotification: (notification) {
          if (notification.overscroll > 0 &&
              _currentPhoto == photos.length - 1) {
            widget.onOverscrollNext();
          } else if (notification.overscroll < 0 && _currentPhoto == 0) {
            widget.onOverscrollPrevious();
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
                onPageChanged: (i) => setState(() => _currentPhoto = i),
                children: [
                  for (final photo in photos)
                    Image.file(
                      File(photo.filePath),
                      width: double.infinity,
                      height: height,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: colors.paper),
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
