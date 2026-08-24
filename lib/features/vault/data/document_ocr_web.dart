import 'document_ocr_service.dart';

/// ML Kit is an on-device native SDK with no browser equivalent, and
/// nothing in the app may block on it: OCR is prefill, never a gate
/// (CLAUDE.md hard rule 4). On the web the field simply starts empty and
/// the user types, exactly as when recognition finds no text.
class UnavailableDocumentTextRecognizer implements DocumentTextRecognizer {
  const UnavailableDocumentTextRecognizer();

  @override
  Future<String> extractText(String imagePath) async => '';
}

/// Rasterizing pages only exists to feed the recognizer above, so with no
/// recognizer there is nothing to rasterize for.
class UnavailablePdfPageRasterizer implements PdfPageRasterizer {
  const UnavailablePdfPageRasterizer();

  @override
  Future<List<String>> rasterize(String pdfPath, {required int maxPages}) async
      => const [];
}

DocumentTextRecognizer createTextRecognizer() =>
    const UnavailableDocumentTextRecognizer();

PdfPageRasterizer createPdfRasterizer() => const UnavailablePdfPageRasterizer();
