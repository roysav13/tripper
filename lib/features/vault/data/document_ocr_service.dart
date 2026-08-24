import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/platform/scratch_file.dart';
import '../domain/html_text.dart';
import 'document_ocr_io.dart'
    if (dart.library.js_interop) 'document_ocr_web.dart';

/// Thin seam over text recognition (M5.4) so nothing outside this feature
/// touches the real plugin — same pattern as `NotificationScheduler`
/// (M5.1). Fully on-device, zero network, zero cost (SPEC §3.2.1).
abstract interface class DocumentTextRecognizer {
  /// Raw recognized text from the image at [imagePath], or '' when
  /// recognition fails for any reason — OCR is an enhancement, never a
  /// gate (CLAUDE.md hard rule 4 spirit), so failure degrades to "no
  /// prefill" rather than surfacing an error. On the web there is no
  /// on-device recognizer at all, and '' is likewise the answer.
  Future<String> extractText(String imagePath);
}

/// Real ML Kit on Android, a no-op on the web (see `document_ocr_web.dart`).
/// In the test VM the plugin channel doesn't exist; the ML Kit
/// implementation already swallows that into '', so widget tests that
/// don't care about OCR need no override, and tests that do exercise it
/// override with a fake returning fixture text.
final documentTextRecognizerProvider =
    Provider<DocumentTextRecognizer>((ref) => createTextRecognizer());

/// Renders PDF pages to scratch PNGs so the recognizer (images only) can
/// read them — the bridge that gives PDFs the same OCR prefill as photos
/// (M5.4 extension, user request 2026-07-23). Seam for testability, same
/// pattern as [DocumentTextRecognizer].
abstract interface class PdfPageRasterizer {
  /// Scratch handles for up to [maxPages] pages, `[]` on any failure.
  /// Caller owns cleanup via `deleteScratchFile`.
  Future<List<String>> rasterize(String pdfPath, {required int maxPages});
}

final pdfPageRasterizerProvider =
    Provider<PdfPageRasterizer>((ref) => createPdfRasterizer());

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

  /// [handle] is whatever the picker gave us — a path on Android, a
  /// `blob:` URL in the browser. Pass [fileName] whenever the real name
  /// is known: a blob URL carries no extension, and the extension is how
  /// this picks an extraction route.
  Future<String> extract(String handle, {String? fileName}) async {
    final path = handle;
    final ext =
        p.extension(fileName ?? path).replaceFirst('.', '').toLowerCase();
    if (_imageExtensions.contains(ext)) {
      return _recognizer.extractText(path);
    }
    if (_htmlExtensions.contains(ext)) {
      try {
        // Bytes, not readAsString: saved-email HTML is often UTF-16 or
        // Windows-1252, and a strict UTF-8 decode throws on those.
        // decodeTextBytes sniffs the encoding and never throws. XFile
        // rather than File so a browser's `blob:` handle reads too.
        final bytes = await XFile(path).readAsBytes();
        return htmlToPlainText(decodeTextBytes(bytes));
      } catch (e) {
        if (kDebugMode) debugPrint('[ocr] html read failed: $e');
        return '';
      }
    }
    if (ext != 'pdf') return '';

    final pageHandles =
        await _rasterizer.rasterize(path, maxPages: _pdfPagesToScan);
    final buffer = StringBuffer();
    for (final handle in pageHandles) {
      buffer.writeln(await _recognizer.extractText(handle));
      await deleteScratchFile(handle);
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
