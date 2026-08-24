import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/platform/scratch_file.dart';
import 'document_ocr_service.dart';

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

class PdfxPageRasterizer implements PdfPageRasterizer {
  @override
  Future<List<String>> rasterize(
    String pdfPath, {
    required int maxPages,
  }) async {
    final handles = <String>[];
    try {
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
            final handle = await writeScratchFile(
              image.bytes,
              extension: '.png',
              prefix: 'tripper_ocr_${i}_',
            );
            if (handle != null) handles.add(handle);
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
    return handles;
  }
}

/// Real ML Kit and pdfx. Selected by the conditional import in
/// `document_ocr_service.dart`.
DocumentTextRecognizer createTextRecognizer() => MlkitDocumentTextRecognizer();

PdfPageRasterizer createPdfRasterizer() => PdfxPageRasterizer();
