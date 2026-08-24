import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/journal_photo.dart';

/// Full-screen, pinch-zoomable gallery for one entry's photos — opened by
/// tapping a photo in the presentation sheet's carousel ([initialIndex]
/// matches whichever photo was showing there). Swiping here reports the
/// new index via [onPageChanged] so the carousel resumes on the same
/// photo after this viewer is dismissed.
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
        saveToGallery: saveToGallery ?? Gal.putImage,
      ),
    ),
  );
}

class _JournalPhotoViewer extends StatefulWidget {
  const _JournalPhotoViewer({
    required this.photos,
    required this.initialIndex,
    required this.onPageChanged,
    required this.saveToGallery,
  });

  final List<JournalPhoto> photos;
  final int initialIndex;
  final void Function(int index) onPageChanged;
  final Future<void> Function(String filePath) saveToGallery;

  @override
  State<_JournalPhotoViewer> createState() => _JournalPhotoViewerState();
}

class _JournalPhotoViewerState extends State<_JournalPhotoViewer> {
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
    try {
      await widget.saveToGallery(path);
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
              imageProvider: FileImage(File(widget.photos[index].filePath)),
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
