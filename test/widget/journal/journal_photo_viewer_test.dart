import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/domain/journal_photo.dart';
import 'package:tripper/features/journal/presentation/journal_photo_viewer.dart';
import 'package:tripper/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: child,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );

/// Decodes [file] and seats it in the global [imageCache] via a real
/// event-loop turn. `flutter test`'s default binding runs widget code
/// inside a fake-async zone, so a disk-backed [FileImage] never finishes
/// decoding through plain [WidgetTester.pump]/[pumpAndSettle] alone —
/// photo_view's default loading state is an indeterminate
/// [CircularProgressIndicator], whose repeating animation then keeps
/// `pumpAndSettle` from ever settling. Warming the cache here (inside
/// [WidgetTester.runAsync], which briefly runs in the real zone) means
/// the widget's own later `resolve()` call is a cache hit that completes
/// synchronously within the same build pass, before `build()` reads the
/// loading flag.
Future<void> _warmImageCache(File file) {
  final provider = FileImage(file);
  final stream = provider.resolve(ImageConfiguration.empty);
  final completer = Completer<void>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, synchronousCall) {
      stream.removeListener(listener);
      completer.complete();
    },
    onError: (error, stackTrace) {
      stream.removeListener(listener);
      completer.completeError(error, stackTrace);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

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
    await _warmImageCache(photoA);
    await _warmImageCache(photoB);
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
