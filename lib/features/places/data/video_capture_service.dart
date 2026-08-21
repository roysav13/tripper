import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../core/sharing/tiktok_video_link_service.dart'
    show tiktokHttpClientProvider, tiktokUserAgent;

/// Downloads a resolved TikTok video URL to a temp file. Seam for
/// testability, same pattern as `DocumentTextRecognizer`/
/// `PdfPageRasterizer` — nothing outside this file touches `http` for
/// video bytes.
abstract interface class VideoDownloader {
  /// Temp file path, or null on any failure (offline, non-200, a non-video
  /// body, timeout). Caller owns cleanup of the returned file.
  Future<String?> download(Uri videoUrl);
}

/// Pure — unit-tested directly. A ranged request (see `HttpVideoDownloader`,
/// which always sends `Range: bytes=0-`) is expected to answer 206, not
/// 200 — both mean "here is a real video body".
bool isAcceptableVideoStatus(int statusCode) =>
    statusCode == 200 || statusCode == 206;

class HttpVideoDownloader implements VideoDownloader {
  HttpVideoDownloader(this._client);

  final http.Client _client;

  @override
  Future<String?> download(Uri videoUrl) async {
    try {
      // TikTok's CDN URLs are signed/time-limited and reject a request
      // that doesn't look like it came from the same browser session that
      // loaded the page — same User-Agent as TikTokVideoLinkService, a
      // Referer/Origin pointing at the site (Akamai's edge, fronting this
      // CDN, echoes `access-control-allow-origin: https://www.tiktok.com`
      // on a rejection — it's gating on Origin specifically, not just
      // Referer), a Range header (the edge also allows `range` via CORS,
      // consistent with expecting a real <video>-element-style ranged
      // request rather than a plain full-file GET), and the SAME
      // http.Client instance (see tiktokHttpClientProvider) so any
      // session cookie set while fetching the page is replayed here.
      final response = await _client.get(
        videoUrl,
        headers: {
          'User-Agent': tiktokUserAgent,
          'Referer': 'https://www.tiktok.com/',
          'Origin': 'https://www.tiktok.com',
          'Range': 'bytes=0-',
          // Fetch Metadata headers a real browser's <video> element sends
          // automatically for a cross-origin media request — the video CDN
          // host (v16-webapp-prime.tiktok.com) shares tiktok.com's
          // registrable domain with the Referer/Origin (www.tiktok.com),
          // which is what makes this "same-site" rather than "cross-site".
          // A hand-rolled HTTP client sending none of these is a cheap,
          // header-visible tell that Bot Manager-style rules commonly gate
          // on directly, separate from (and unlike) TLS-level fingerprinting.
          'Sec-Fetch-Dest': 'video',
          'Sec-Fetch-Mode': 'no-cors',
          'Sec-Fetch-Site': 'same-site',
          'Accept': '*/*',
          'sec-ch-ua':
              '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
          'sec-ch-ua-mobile': '?1',
          'sec-ch-ua-platform': '"Android"',
        },
      ).timeout(const Duration(seconds: 30));
      if (!isAcceptableVideoStatus(response.statusCode)) {
        if (kDebugMode) {
          // CDNs are usually explicit about *why* a request was rejected
          // (signature mismatch, referrer check, expired token) — logging
          // it beats guessing at another header to add blind. `.get()`
          // already buffers the whole body (it's `http.Response`, not a
          // streamed response), and a rejection body is small (an error
          // page, not a video), so reading it here is safe.
          final body = response.body;
          debugPrint(
            '[video] GET $videoUrl -> ${response.statusCode}\n'
            '[video] response headers: ${response.headers}\n'
            '[video] response body: '
            '${body.substring(0, body.length < 500 ? body.length : 500)}',
          );
        }
        return null;
      }
      if (kDebugMode) {
        debugPrint('[video] GET $videoUrl -> ${response.statusCode}');
      }
      // A CDN rejection often comes back as a 200 carrying an HTML or JSON
      // error page. Saving that as a `.mp4` only defers the failure to
      // `initialize()`, so reject it here where "couldn't fetch this
      // video" is still the honest answer. The header is advisory — some
      // servers omit it on perfectly good video responses — so only an
      // explicitly non-video type disqualifies the body.
      final contentType = response.headers['content-type'];
      if (contentType != null &&
          !contentType.trim().toLowerCase().startsWith('video/')) {
        if (kDebugMode) {
          debugPrint('[video] download rejected: content-type $contentType');
        }
        return null;
      }
      final tempDir = await getTemporaryDirectory();
      final file = File(
        p.join(
          tempDir.path,
          'tripper_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
        ),
      );
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (e) {
      if (kDebugMode) debugPrint('[video] download failed: $e');
      return null;
    }
  }
}

final videoDownloaderProvider = Provider<VideoDownloader>(
  (ref) => HttpVideoDownloader(ref.watch(tiktokHttpClientProvider)),
);

/// Rasterizes a single still frame from a local video file at a given
/// position — `video_player` (used for the live scrub preview, Task 7)
/// has no frame-grab API of its own, so "capture" re-derives the frame
/// from the file directly via `video_thumbnail`.
abstract interface class VideoFrameCapturer {
  /// Temp PNG path, or null on any failure. Caller owns cleanup.
  Future<String?> captureFrame(String videoPath, Duration position);
}

class VideoThumbnailFrameCapturer implements VideoFrameCapturer {
  @override
  Future<String?> captureFrame(String videoPath, Duration position) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final path = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.PNG,
        timeMs: position.inMilliseconds,
        quality: 100,
      );
      return path;
    } catch (e) {
      if (kDebugMode) debugPrint('[video] frame capture failed: $e');
      return null;
    }
  }
}

final videoFrameCapturerProvider =
    Provider<VideoFrameCapturer>((ref) => VideoThumbnailFrameCapturer());
