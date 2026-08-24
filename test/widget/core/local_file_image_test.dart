import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tripper/core/files/file_vault_service.dart';
import 'package:tripper/core/widgets/local_images.dart';

import '../../helpers/warm_image_cache.dart';

/// 1x1 PNG. Written synchronously below on purpose: real async file IO
/// never completes inside `flutter test`'s fake-async zone, so `await`ing
/// it from a test body hangs (same reason `show_code_screen_test.dart`
/// uses `writeAsBytesSync`).
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  late Directory tempDir;
  late FileVaultService store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('local_file_image');
    store = FileVaultService(() async => tempDir);
  });

  tearDown(() {
    imageCache.clear();
    imageCache.clearLiveImages();
    try {
      tempDir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can hold the handle a beat longer; it's a temp dir.
    }
  });

  Widget host(String storageKey) => MaterialApp(
        home: Image(
          image: LocalFileImage(storageKey, store),
          errorBuilder: (_, __, ___) => const Text('broken'),
        ),
      );

  /// Alternates real-event-loop windows with frames until [target] appears.
  ///
  /// A failing load takes several file-IO hops (`exists`, then `read`, then
  /// the throw), and each hop's continuation only advances while `runAsync`
  /// holds the real event loop — one window is nowhere near enough, and the
  /// number needed isn't stable across machines, so this polls instead of
  /// guessing a delay.
  Future<void> pumpUntil(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (target.evaluate().isNotEmpty) return;
    }
  }

  test('identity is the storage key and scale, never the store', () {
    final otherStore =
        FileVaultService(() async => tempDir, subfolder: 'covers');

    expect(
      LocalFileImage('vault/a.jpg', store),
      LocalFileImage('vault/a.jpg', otherStore),
      reason: 'a rebuild that constructs a fresh store must still hit the '
          'image cache',
    );
    expect(
      LocalFileImage('vault/a.jpg', store).hashCode,
      LocalFileImage('vault/a.jpg', otherStore).hashCode,
    );
    expect(
      LocalFileImage('vault/a.jpg', store),
      isNot(LocalFileImage('vault/b.jpg', store)),
    );
    expect(
      LocalFileImage('vault/a.jpg', store),
      isNot(LocalFileImage('vault/a.jpg', store, scale: 2)),
    );
  });

  testWidgets('renders bytes the store hands back', (tester) async {
    final key = p.join(tempDir.path, 'photo.png');
    File(key).writeAsBytesSync(_pngBytes);

    await tester.runAsync(() => warmLocalImageCache(key));
    await tester.pumpWidget(host(key));
    await tester.pump();

    expect(find.text('broken'), findsNothing);
    final rendered = tester.widget<Image>(find.byType(Image));
    expect((rendered.image as LocalFileImage).storageKey, key);
  });

  testWidgets('a key with no stored file falls through to errorBuilder',
      (tester) async {
    await tester.pumpWidget(host(p.join(tempDir.path, 'gone.png')));
    await pumpUntil(tester, find.text('broken'));

    expect(find.text('broken'), findsOneWidget);
  });

  testWidgets(
      'a stored-but-empty file is treated as missing, not as a corrupt-image '
      'crash', (tester) async {
    // What a half-written import, or a backup restored without its vault
    // contents, leaves behind.
    final key = p.join(tempDir.path, 'empty.png');
    File(key).writeAsBytesSync(const <int>[]);

    await tester.pumpWidget(host(key));
    await pumpUntil(tester, find.text('broken'));

    expect(find.text('broken'), findsOneWidget);
  });
}
