import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the offline PWA.
///
/// On the first online load the service worker isn't controlling the page
/// yet, so none of the boot requests pass through its `fetch` handler and
/// none get cached that way. Anything the shell needs before its first
/// frame must therefore be in `PRECACHE` explicitly — a missing renderer or
/// asset manifest means the installed app doesn't open offline at all, and
/// missing fonts mean it renders in system glyphs. These tests fail if a
/// boot-critical file or a bundled font is added without wiring it in.
void main() {
  late String precache;

  setUp(() {
    final sw = File('web/sw.js').readAsStringSync();
    final match =
        RegExp(r'const PRECACHE = \[(.*?)\];', dotAll: true).firstMatch(sw);
    expect(match, isNotNull, reason: 'PRECACHE array not found in web/sw.js');
    precache = match!.group(1)!;
  });

  test('web/sw.js precaches the boot-critical app shell', () {
    const bootCritical = [
      // Renderer — both variants; Flutter never falls back between them.
      'canvaskit/canvaskit.js',
      'canvaskit/canvaskit.wasm',
      'canvaskit/chromium/canvaskit.js',
      'canvaskit/chromium/canvaskit.wasm',
      // Asset resolution.
      'assets/AssetManifest.bin.json',
      'assets/FontManifest.json',
      // Loaded by index.html itself.
      'pdfjs/build/pdf.min.mjs',
      // The Dart bundle and the local SQLite engine.
      'main.dart.js',
      'sqlite3.wasm',
      'drift_worker.js',
    ];
    for (final path in bootCritical) {
      expect(
        precache,
        contains(path),
        reason: '$path is needed for a cold offline launch but is missing '
            'from web/sw.js PRECACHE',
      );
    }
  });

  test('web/sw.js precaches every font declared in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    // pubspec lists `- asset: assets/fonts/X.ttf`; Flutter web serves that
    // under an extra `assets/` prefix, i.e. `assets/assets/fonts/X.ttf`.
    final declared = RegExp(r'-\s*asset:\s*(assets/fonts/[^\s]+)')
        .allMatches(pubspec)
        .map((m) => 'assets/${m.group(1)}')
        .toList();
    expect(
      declared,
      isNotEmpty,
      reason: 'no font assets found in pubspec.yaml',
    );

    for (final path in declared) {
      expect(
        precache,
        contains(path),
        reason: '$path is bundled but missing from web/sw.js PRECACHE',
      );
    }
    expect(precache, contains('assets/fonts/MaterialIcons-Regular.otf'));
  });
}
