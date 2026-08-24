import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../core/files/local_file_store.dart';
import '../../../core/platform/save_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/local_images.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/journal_photo.dart';

/// Full-screen, pinch-zoomable gallery for one entry's photos — opened by
/// tapping a photo in the presentation sheet's carousel ([initialIndex]
/// matches whichever photo was showing there). Swiping here reports the
/// new index via [onPageChanged] so the carousel resumes on the same
/// photo after this viewer is dismissed.
///
/// [saveToGallery] defaults to the platform's own "save this photo"
/// route — the system gallery on Android, a download on the web — and is
/// injectable so tests never touch either.
Future<void> showJournalPhotoViewer(
  BuildContext context, {
  required List<JournalPhoto> photos,
  required int initialIndex,
  required void Function(int index) onPageChanged,
  Future<void> Function(String filePath)? saveToGallery,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _JournalPhotoViewer(
        photos: photos,
        initialIndex: initialIndex,
        onPageChanged: onPageChanged,
        saveToGallery: saveToGallery,
      ),
    ),
  );
}

class _JournalPhotoViewer extends ConsumerStatefulWidget {
  const _JournalPhotoViewer({
    required this.photos,
    required this.initialIndex,
    required this.onPageChanged,
    required this.saveToGallery,
  });

  final List<JournalPhoto> photos;
  final int initialIndex;
  final void Function(int index) onPageChanged;

  /// Null means "use the platform default" — resolved in the State,
  /// where a `ref` is available to reach the file store.
  final Future<void> Function(String filePath)? saveToGallery;

  @override
  ConsumerState<_JournalPhotoViewer> createState() =>
      _JournalPhotoViewerState();
}

class _JournalPhotoViewerState extends ConsumerState<_JournalPhotoViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _currentIndex = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDownload() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final path = widget.photos[_currentIndex].filePath;
    final save = widget.saveToGallery ??
        (String key) => saveImageToDevice(key, ref.read(fileVaultServiceProvider));
    try {
      await save(path);
      messenger.showSnackBar(SnackBar(content: Text(l10n.journalPhotoSaved)));
    } catch (_) {
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.journalPhotoSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.inkPrimary,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            pageController: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              widget.onPageChanged(index);
            },
            backgroundDecoration: BoxDecoration(color: colors.inkPrimary),
            builder: (context, index) => PhotoViewGalleryPageOptions(
              imageProvider: LocalFileImage(
                widget.photos[index].filePath,
                ref.watch(fileVaultServiceProvider),
              ),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
          ),
          PositionedDirectional(
            top: 8,
            start: 8,
            child: SafeArea(
              child: _circleButton(
                colors,
                icon: Icons.close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          PositionedDirectional(
            top: 8,
            end: 8,
            child: SafeArea(
              child: _circleButton(
                colors,
                icon: Icons.download,
                onPressed: _handleDownload,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(
    AppColors colors, {
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, color: colors.surface, size: 20),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: colors.inkPrimary.withValues(alpha: 0.32),
        shape: const CircleBorder(),
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
