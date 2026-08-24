import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/features/vault/presentation/show_code_screen.dart';
import 'package:tripper/l10n/app_localizations.dart';

/// 1x1 PNG. Sync file IO + runAsync below: real IO never completes inside
/// the fake-async test zone, so async setup/teardown would hang the test.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// ProviderScope because the screen reads its file through
/// `fileVaultServiceProvider`; the default filesystem-backed store reads
/// the absolute temp paths these tests use.
Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
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

void main() {
  test('canShow accepts images and PDFs, with extension fallback', () {
    final pdf = Document(
      id: 'a',
      title: 'Ticket',
      category: DocumentCategory.flight,
      createdAt: DateTime(2026, 7, 19),
      filePath: '/x/a.pdf',
      mimeType: 'application/pdf',
    );
    final image = Document(
      id: 'b',
      title: 'Boarding pass',
      category: DocumentCategory.flight,
      createdAt: DateTime(2026, 7, 19),
      filePath: '/x/b.png',
      mimeType: 'image/png',
    );
    // Shared-in file where mime detection failed — extension decides.
    final noMime = Document(
      id: 'd',
      title: 'Shared pass',
      category: DocumentCategory.flight,
      createdAt: DateTime(2026, 7, 19),
      filePath: '/x/d.PDF',
    );
    final manual = Document(
      id: 'c',
      title: 'Conf code',
      category: DocumentCategory.flight,
      createdAt: DateTime(2026, 7, 19),
    );
    expect(ShowCodeScreen.canShow(pdf), isTrue);
    expect(ShowCodeScreen.canShow(image), isTrue);
    expect(ShowCodeScreen.canShow(noMime), isTrue);
    expect(ShowCodeScreen.canShow(manual), isFalse);
  });

  testWidgets('renders the image full-screen on white', (tester) async {
    final dir = Directory.systemTemp.createTempSync('show_code');
    addTearDown(() {
      // Windows may still hold the image file handle via the image cache.
      imageCache.clear();
      imageCache.clearLiveImages();
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Temp dir — the OS cleans it up; don't fail the test over a lock.
      }
    });
    final file = File('${dir.path}/pass.png')..writeAsBytesSync(_pngBytes);

    final doc = Document(
      id: 'b',
      title: 'Boarding pass',
      category: DocumentCategory.flight,
      createdAt: DateTime(2026, 7, 19),
      filePath: file.path,
      mimeType: 'image/png',
    );
    await tester.pumpWidget(_wrap(ShowCodeScreen(doc: doc)));
    // Let the real event loop deliver the file read + decode.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.text('Boarding pass'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('missing file shows the fallback message', (tester) async {
    final doc = Document(
      id: 'x',
      title: 'Gone',
      category: DocumentCategory.flight,
      createdAt: DateTime(2026, 7, 19),
      filePath: '/nonexistent/pass.png',
      mimeType: 'image/png',
    );
    await tester.pumpWidget(_wrap(ShowCodeScreen(doc: doc)));
    // Let the real event loop deliver the file-not-found error.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.textContaining('file is missing'), findsOneWidget);
  });
}
