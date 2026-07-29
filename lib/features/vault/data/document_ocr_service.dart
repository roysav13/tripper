import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../domain/html_text.dart';

/// Thin seam over ML-Kit text recognition (M5.4) so nothing outside this
/// file touches the real plugin — same pattern as `NotificationScheduler`
/// (M5.1). Fully on-device, zero network, zero cost (SPEC §3.2.1).
abstract interface class DocumentTextRecognizer {
  /// Raw recognized text from the image at [imagePath], or '' when
  /// recognition fails for any reason — OCR is an enhancement, never a
  /// gate (CLAUDE.md hard rule 4 spirit), so failure degrades to "no
  /// prefill" rather than surfacing an error.
  Future<String> extractText(String imagePath);
}

class MlkitDocumentTextRecognizer implements DocumentTextRecognizer {
  @override
  Future<String> extractText(String imagePath) async {
    final recognizer = TextRecognizer();
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      return result.text;
    } catch (e) {
      // Degrade to no-prefill, but say why in debug — a swallowed plugin
      // error is indistinguishable from a blank photo otherwise.
      if (kDebugMode) debugPrint('[ocr] recognition failed: $e');
      return '';
    } finally {
      await recognizer.close();
    }
  }
}

/// Real ML-Kit by default. In the test VM the plugin channel doesn't
/// exist; [MlkitDocumentTextRecognizer] already swallows that into '',
/// so widget tests that don't care about OCR need no override, and tests
/// that do exercise it override with a fake returning fixture text.
final documentTextRecognizerProvider = Provider<DocumentTextRecognizer>(
  (ref) => MlkitDocumentTextRecognizer(),
);

/// Renders PDF pages to temp PNG files so ML-Kit (images only) can read
/// them — the bridge that gives PDFs the same OCR prefill as photos
/// (M5.4 extension, user request 2026-07-23). Seam for testability, same
/// pattern as [DocumentTextRecognizer].
abstract interface class PdfPageRasterizer {
  /// Temp PNG paths for up to [maxPages] pages, `[]` on any failure.
  /// Caller owns cleanup of the returned files.
  Future<List<String>> rasterize(String pdfPath, {required int maxPages});
}

class PdfxPageRasterizer implements PdfPageRasterizer {
  @override
  Future<List<String>> rasterize(
    String pdfPath, {
    required int maxPages,
  }) async {
    final paths = <String>[];
    try {
      final tempDir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final doc = await PdfDocument.openFile(pdfPath);
      try {
        final pageCount = doc.pagesCount < maxPages ? doc.pagesCount : maxPages;
        for (var i = 1; i <= pageCount; i++) {
          final page = await doc.getPage(i);
          try {
            // 3x the PDF's native point size ≈ 216dpi — enough for the
            // small MRZ glyphs; 1x (72dpi) is too coarse for OCR.
            final image = await page.render(
              width: page.width * 3,
              height: page.height * 3,
              format: PdfPageImageFormat.png,
            );
            if (image == null) continue;
            final file =
                File(p.join(tempDir.path, 'tripper_ocr_${stamp}_$i.png'));
            await file.writeAsBytes(image.bytes);
            paths.add(file.path);
          } finally {
            await page.close();
          }
        }
      } finally {
        await doc.close();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ocr] pdf rasterization failed: $e');
    }
    return paths;
  }
}

final pdfPageRasterizerProvider = Provider<PdfPageRasterizer>(
  (ref) => PdfxPageRasterizer(),
);

/// Routes a picked file to the right text-extraction path by extension:
/// images go straight to the recognizer, PDFs get their first pages
/// rasterized first (passport scans exported as PDF are typically page
/// 1; booking PDFs simply won't contain an MRZ and prefill nothing),
/// and HTML files (airline confirmation emails saved as .html) are read
/// directly and tag-stripped — no OCR involved at all. Anything else —
/// or any failure — degrades to ''.
class DocumentTextExtractor {
  DocumentTextExtractor(this._recognizer, this._rasterizer);

  final DocumentTextRecognizer _recognizer;
  final PdfPageRasterizer _rasterizer;

  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  static const _htmlExtensions = {'html', 'htm'};
  static const _pdfPagesToScan = 3;

  Future<String> extract(String path) async {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (_imageExtensions.contains(ext)) {
      return _recognizer.extractText(path);
    }
    if (_htmlExtensions.contains(ext)) {
      try {
        // Bytes, not readAsString: saved-email HTML is often UTF-16 or
        // Windows-1252, and a strict UTF-8 decode throws on those.
        // decodeTextBytes sniffs the encoding and never throws.
        final bytes = await File(path).readAsBytes();
        return htmlToPlainText(decodeTextBytes(bytes));
      } catch (e) {
        if (kDebugMode) debugPrint('[ocr] html read failed: $e');
        return '';
      }
    }
    if (ext != 'pdf') return '';

    final pagePaths =
        await _rasterizer.rasterize(path, maxPages: _pdfPagesToScan);
    final buffer = StringBuffer();
    for (final pagePath in pagePaths) {
      buffer.writeln(await _recognizer.extractText(pagePath));
      // Best-effort temp cleanup — a leftover temp file is harmless, a
      // crash over one would not be.
      try {
        await File(pagePath).delete();
      } catch (_) {}
    }
    return buffer.toString().trim();
  }
}

final documentTextExtractorProvider = Provider<DocumentTextExtractor>(
  (ref) => DocumentTextExtractor(
    ref.watch(documentTextRecognizerProvider),
    ref.watch(pdfPageRasterizerProvider),
  ),
);
