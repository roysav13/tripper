import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/paper_card.dart';
import '../domain/journal_entry.dart';

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
  static const _photoHeight = 84.0;

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
                              height: _photoHeight,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _placeholder(colors),
                            )
                          : _placeholder(colors),
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
                            entry.summary,
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

  Widget _placeholder(AppColors colors) => Container(
        width: width,
        height: _photoHeight,
        color: colors.paper,
        alignment: Alignment.center,
        child: Icon(Icons.edit_note, color: colors.inkMuted),
      );
}
