import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/domain/journal_photo.dart';
import 'package:tripper/features/journal/presentation/journal_photo_viewer.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/warm_image_cache.dart';

/// ProviderScope because the viewer reads photos through
/// `fileVaultServiceProvider`. The default (real, filesystem-backed) store
/// is what these tests want: the keys below are absolute temp-file paths.
Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: child,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

/// Two on-disk PNGs plus a [JournalPhoto] list pointing at them, warmed
/// into [imageCache] so photo_view resolves them synchronously in tests.
Future<(Directory dir, List<JournalPhoto> photos)> _setUpPhotos(
  WidgetTester tester,
) async {
  final dir = Directory.systemTemp.createTempSync('journal_photo_viewer');
  addTearDown(() {
    imageCache.clear();
    imageCache.clearLiveImages();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // OS cleans up temp dirs — don't fail the test over a lock.
    }
  });
  final photoA = File('${dir.path}/a.png')..writeAsBytesSync(_pngBytes);
  final photoB = File('${dir.path}/b.png')..writeAsBytesSync(_pngBytes);
  final photos = [
    JournalPhoto(id: 'p1', filePath: photoA.path),
    JournalPhoto(id: 'p2', filePath: photoB.path),
  ];
  await tester.runAsync(() async {
    await warmLocalImageCache(photoA.path);
    await warmLocalImageCache(photoB.path);
  });
  return (dir, photos);
}

void main() {
  testWidgets(
      'opens a full-screen PhotoViewGallery at the given index, '
      'reports page changes, and closes on tap', (tester) async {
    final (_, photos) = await _setUpPhotos(tester);

    int? reportedIndex;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showJournalPhotoViewer(
              context,
              photos: photos,
              initialIndex: 1,
              onPageChanged: (i) => reportedIndex = i,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoViewGallery), findsOneWidget);

    await tester.drag(find.byType(PhotoViewGallery), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(reportedIndex, 0);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewGallery), findsNothing);
  });

  testWidgets(
      'download icon saves the currently displayed photo and shows a '
      'success snackbar', (tester) async {
    final (_, photos) = await _setUpPhotos(tester);

    String? savedPath;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showJournalPhotoViewer(
              context,
              photos: photos,
              initialIndex: 1,
              onPageChanged: (_) {},
              saveToGallery: (path) async => savedPath = path,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();

    expect(savedPath, photos[1].filePath);
    expect(find.text('Saved to Photos'), findsOneWidget);
  });

  testWidgets(
      'download icon shows a failure snackbar when saving fails',
      (tester) async {
    final (_, photos) = await _setUpPhotos(tester);

    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showJournalPhotoViewer(
              context,
              photos: photos,
              initialIndex: 0,
              onPageChanged: (_) {},
              saveToGallery: (path) async => throw Exception('denied'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't save photo"), findsOneWidget);
  });
}

final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);
