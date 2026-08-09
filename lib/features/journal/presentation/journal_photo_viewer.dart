import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../core/theme/app_colors.dart';
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
      ),
    ),
  );
}

class _JournalPhotoViewer extends StatefulWidget {
  const _JournalPhotoViewer({
    required this.photos,
    required this.initialIndex,
    required this.onPageChanged,
  });

  final List<JournalPhoto> photos;
  final int initialIndex;
  final void Function(int index) onPageChanged;

  @override
  State<_JournalPhotoViewer> createState() => _JournalPhotoViewerState();
}

class _JournalPhotoViewerState extends State<_JournalPhotoViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
            onPageChanged: widget.onPageChanged,
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
              child: IconButton(
                icon: Icon(Icons.close, color: colors.surface, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: colors.inkPrimary.withValues(alpha: 0.32),
                  shape: const CircleBorder(),
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
