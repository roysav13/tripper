import 'dart:io';

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
    final colors = context.colors;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  widget.onPageChanged(index);
                },
                children: [
                  for (final entry in widget.entries)
                    _JournalEntryPresentationPage(
                      entry: entry,
                      onEdit: () => _handleEdit(entry),
                      onDelete: () => _handleDelete(entry),
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
}

class _JournalEntryPresentationPage extends StatelessWidget {
  const _JournalEntryPresentationPage({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final JournalEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final placeName = entry.placeName;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          entry.hasPhotos ? _photoHeader(colors, l10n) : _plainHeader(colors, l10n),
          Padding(
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
                      Icon(Icons.place_outlined, size: 14, color: colors.accent),
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
                  entry.summary.isEmpty ? l10n.journalUntitledEntry : entry.summary,
                  style: AppTextStyles.body.copyWith(
                    color:
                        entry.summary.isEmpty ? colors.inkMuted : colors.inkPrimary,
                    fontStyle:
                        entry.summary.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoHeader(AppColors colors, AppLocalizations l10n) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Image.file(
            File(entry.photos.first.filePath),
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(height: 220, color: colors.paper),
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
        PositionedDirectional(
          top: 8,
          start: 0,
          end: 0,
          child: Center(child: _handle(colors.surface.withValues(alpha: 0.85))),
        ),
        PositionedDirectional(
          top: 2,
          end: 2,
          child: _menu(l10n, iconColor: colors.surface, deleteColor: colors.error),
        ),
      ],
    );
  }

  Widget _plainHeader(AppColors colors, AppLocalizations l10n) {
    // Explicit height, not left to the Stack's own non-positioned child
    // (the handle) to determine: this sits inside a SingleChildScrollView,
    // which hands the Stack unbounded height, so a loose-fit Stack would
    // shrink-wrap to just the tiny handle's size — leaving the menu
    // button positioned outside the Stack's own hit-testable bounds
    // (painted, but untappable).
    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 12),
            child: Center(child: _handle(colors.hairline)),
          ),
          PositionedDirectional(
            top: 4,
            end: 2,
            child: _menu(l10n, iconColor: colors.inkMuted, deleteColor: colors.error),
          ),
        ],
      ),
    );
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
    required Color iconColor,
    required Color deleteColor,
  }) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: iconColor),
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
  }
}
