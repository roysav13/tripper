import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/vault/data/document_ocr_service.dart';

class _FakeRecognizer implements DocumentTextRecognizer {
  final List<String> requestedPaths = [];
  final Map<String, String> textByPath;

  _FakeRecognizer([this.textByPath = const {}]);

  @override
  Future<String> extractText(String imagePath) async {
    requestedPaths.add(imagePath);
    return textByPath[imagePath] ?? 'text-of-$imagePath';
  }
}

class _FakeRasterizer implements PdfPageRasterizer {
  _FakeRasterizer(this.pagePaths);

  final List<String> pagePaths;
  final List<(String, int)> calls = [];

  @override
  Future<List<String>> rasterize(
    String pdfPath, {
    required int maxPages,
  }) async {
    calls.add((pdfPath, maxPages));
    return pagePaths;
  }
}

void main() {
  test('images go straight to the recognizer, no rasterization', () async {
    final recognizer = _FakeRecognizer();
    final rasterizer = _FakeRasterizer([]);
    final extractor = DocumentTextExtractor(recognizer, rasterizer);

    final text = await extractor.extract('/photos/passport.JPG');
    expect(text, 'text-of-/photos/passport.JPG');
    expect(rasterizer.calls, isEmpty);
  });

  test('pdf pages are rasterized then each recognized, texts joined', () async {
    // Real temp files so the extractor's cleanup pass has something to
    // delete.
    final dir = await Directory.systemTemp.createTemp('extractor_test');
    addTearDown(() => dir.delete(recursive: true));
    final page1 = File('${dir.path}/p1.png')..writeAsStringSync('x');
    final page2 = File('${dir.path}/p2.png')..writeAsStringSync('x');

    final recognizer = _FakeRecognizer({
      page1.path: 'line one',
      page2.path: 'line two',
    });
    final rasterizer = _FakeRasterizer([page1.path, page2.path]);
    final extractor = DocumentTextExtractor(recognizer, rasterizer);

    final text = await extractor.extract('/docs/booking.pdf');
    expect(text, 'line one\nline two');
    expect(rasterizer.calls.single.$1, '/docs/booking.pdf');
    expect(recognizer.requestedPaths, [page1.path, page2.path]);
  });

  test('temp page files are deleted after recognition', () async {
    final dir = await Directory.systemTemp.createTemp('extractor_test');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final page = File('${dir.path}/p1.png')..writeAsStringSync('x');

    final extractor =
        DocumentTextExtractor(_FakeRecognizer(), _FakeRasterizer([page.path]));
    await extractor.extract('/docs/scan.pdf');
    expect(page.existsSync(), isFalse);
  });

  test('html files are read and tag-stripped, no OCR involved', () async {
    final dir = await Directory.systemTemp.createTemp('extractor_test');
    addTearDown(() => dir.delete(recursive: true));
    final htmlFile = File('${dir.path}/booking.html')
      ..writeAsStringSync('<p>Flight <b>LY315</b></p><p>PNR: X4B7QZ</p>');

    final recognizer = _FakeRecognizer();
    final rasterizer = _FakeRasterizer([]);
    final extractor = DocumentTextExtractor(recognizer, rasterizer);

    final text = await extractor.extract(htmlFile.path);
    expect(text, 'Flight LY315\nPNR: X4B7QZ');
    expect(recognizer.requestedPaths, isEmpty);
    expect(rasterizer.calls, isEmpty);
  });

  test(
      'UTF-16 html (how saved emails commonly arrive) decodes instead of '
      'failing — regression for the on-device 2026-07-23 crash', () async {
    final dir = await Directory.systemTemp.createTemp('extractor_test');
    addTearDown(() => dir.delete(recursive: true));
    const html = '<p>Flight <b>LY315</b></p>';
    // UTF-16 LE with BOM.
    final bytes = <int>[0xFF, 0xFE];
    for (final unit in html.codeUnits) {
      bytes
        ..add(unit & 0xFF)
        ..add(unit >> 8);
    }
    final htmlFile = File('${dir.path}/utf16.html')..writeAsBytesSync(bytes);

    final extractor =
        DocumentTextExtractor(_FakeRecognizer(), _FakeRasterizer([]));
    expect(await extractor.extract(htmlFile.path), 'Flight LY315');
  });

  test('a missing html file degrades to empty text, no crash', () async {
    final extractor =
        DocumentTextExtractor(_FakeRecognizer(), _FakeRasterizer([]));
    expect(await extractor.extract('/nowhere/gone.html'), '');
  });

  test('pdf that fails to rasterize yields empty text, no crash', () async {
    final extractor =
        DocumentTextExtractor(_FakeRecognizer(), _FakeRasterizer([]));
    expect(await extractor.extract('/docs/corrupt.pdf'), '');
  });

  test(
      'unsupported extensions yield empty text without touching either '
      'dependency', () async {
    final recognizer = _FakeRecognizer();
    final rasterizer = _FakeRasterizer([]);
    final extractor = DocumentTextExtractor(recognizer, rasterizer);

    expect(await extractor.extract('/docs/notes.txt'), '');
    expect(recognizer.requestedPaths, isEmpty);
    expect(rasterizer.calls, isEmpty);
  });
}
