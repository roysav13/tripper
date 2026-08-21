import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Downloads a TikTok oEmbed cover-image URL to a temp file for OCR. Seam
/// for testability, same pattern as `DocumentTextRecognizer`/
/// `PdfPageRasterizer` (`lib/features/vault/data/document_ocr_service.dart`)
/// — nothing outside this file touches `http` for the thumbnail bytes.
///
/// Unlike the video-playback CDN this feature originally tried to fetch
/// from, oEmbed thumbnail URLs are meant for arbitrary third-party
/// fetching and take a plain request with no special headers — confirmed
/// on-device.
abstract interface class TikTokThumbnailDownloader {
  /// Temp file path, or null on any failure (offline, non-200, a non-image
  /// body, timeout). Caller owns cleanup of the returned file.
  Future<String?> download(String thumbnailUrl);
}

class HttpTikTokThumbnailDownloader implements TikTokThumbnailDownloader {
  HttpTikTokThumbnailDownloader(this._client);

  final http.Client _client;

  @override
  Future<String?> download(String thumbnailUrl) async {
    try {
      final uri = Uri.tryParse(thumbnailUrl);
      if (uri == null) return null;
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (kDebugMode) {
        debugPrint('[tiktok] thumbnail GET -> ${response.statusCode}');
      }
      if (response.statusCode != 200) return null;
      // Same defensive check as the (now-removed) video downloader: a
      // rejection can come back as a 200 carrying an HTML error page. The
      // header is advisory (omitted on some perfectly good responses), so
      // only an explicitly non-image type disqualifies the body.
      final contentType = response.headers['content-type'];
      if (contentType != null &&
          !contentType.trim().toLowerCase().startsWith('image/')) {
        if (kDebugMode) {
          debugPrint(
            '[tiktok] thumbnail download rejected: content-type $contentType',
          );
        }
        return null;
      }
      final tempDir = await getTemporaryDirectory();
      final file = File(
        p.join(
          tempDir.path,
          'tripper_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (e) {
      if (kDebugMode) debugPrint('[tiktok] thumbnail download failed: $e');
      return null;
    }
  }
}

final tiktokThumbnailDownloaderProvider = Provider<TikTokThumbnailDownloader>(
  (ref) => HttpTikTokThumbnailDownloader(http.Client()),
);
