import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/document.dart';

/// The "standing at the gate" screen: the document full-screen on white,
/// brightness forced to max, screen kept awake. Boarding passes are usually
/// PDFs — the first page is rendered inline. Always light — scanners and
/// gate agents don't care about dark mode.
class ShowCodeScreen extends StatefulWidget {
  const ShowCodeScreen({super.key, required this.doc});

  final Document doc;

  static bool _isImage(Document doc) =>
      (doc.mimeType?.startsWith('image/') ?? false) ||
      const ['.jpg', '.jpeg', '.png', '.webp']
          .contains(p.extension(doc.filePath ?? '').toLowerCase());

  static bool _isPdf(Document doc) =>
      doc.mimeType == 'application/pdf' ||
      p.extension(doc.filePath ?? '').toLowerCase() == '.pdf';

  static bool canShow(Document doc) =>
      doc.hasFile && (_isImage(doc) || _isPdf(doc));

  static Future<void> open(BuildContext context, Document doc) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => ShowCodeScreen(doc: doc),
      ),
    );
  }

  @override
  State<ShowCodeScreen> createState() => _ShowCodeScreenState();
}

class _ShowCodeScreenState extends State<ShowCodeScreen> {
  Future<Uint8List?>? _pdfPage;

  @override
  void initState() {
    super.initState();
    // Best effort — never let a platform quirk break the gate moment.
    _tryPlatform(() => ScreenBrightness().setApplicationScreenBrightness(1.0));
    _tryPlatform(WakelockPlus.enable);
    if (ShowCodeScreen._isPdf(widget.doc)) {
      _pdfPage = _renderPdfFirstPage(widget.doc.filePath!);
    }
  }

  @override
  void dispose() {
    _tryPlatform(
      () => ScreenBrightness().resetApplicationScreenBrightness(),
    );
    _tryPlatform(WakelockPlus.disable);
    super.dispose();
  }

  Future<void> _tryPlatform(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Missing plugin (tests) or unsupported device — ignore.
    }
  }

  /// Render at 3x for crisp barcode edges — scanners need contrast.
  Future<Uint8List?> _renderPdfFirstPage(String path) async {
    PdfDocument? doc;
    PdfPage? page;
    try {
      doc = await PdfDocument.openFile(path);
      page = await doc.getPage(1);
      final image = await page.render(
        width: page.width * 3,
        height: page.height * 3,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      return image?.bytes;
    } catch (_) {
      return null;
    } finally {
      await page?.close();
      await doc?.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
          widget.doc.title,
          style: const TextStyle(fontSize: 17, color: Colors.black87),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.cancel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Center(
        child: _pdfPage != null
            ? FutureBuilder<Uint8List?>(
                future: _pdfPage,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const CircularProgressIndicator(
                      color: Colors.black26,
                    );
                  }
                  final bytes = snapshot.data;
                  if (bytes == null) return _fallback(l10n);
                  return _viewer(Image.memory(bytes, fit: BoxFit.contain));
                },
              )
            : _viewer(
                Image.file(
                  File(widget.doc.filePath!),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) => Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.showCodeFileMissing,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _viewer(Widget child) => InteractiveViewer(maxScale: 6, child: child);

  Widget _fallback(AppLocalizations l10n) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.showCodePdfFallback,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => OpenFilex.open(widget.doc.filePath!),
              child: Text(
                l10n.docActionOpen,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
      );
}
