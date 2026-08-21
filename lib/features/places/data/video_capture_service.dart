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

class HttpVideoDownloader implements VideoDownloader {
  HttpVideoDownloader(this._client);

  final http.Client _client;

  @override
  Future<String?> download(Uri videoUrl) async {
    try {
      // TikTok's CDN URLs are signed/time-limited and reject a request
      // that doesn't look like it came from the same browser session that
      // loaded the page — same User-Agent as TikTokVideoLinkService, a
      // Referer pointing at the site, and (critically) the SAME
      // http.Client instance (see tiktokHttpClientProvider) so any
      // session cookie set while fetching the page is replayed here.
      final response = await _client.get(
        videoUrl,
        headers: {
          'User-Agent': tiktokUserAgent,
          'Referer': 'https://www.tiktok.com/',
        },
      ).timeout(const Duration(seconds: 30));
      if (kDebugMode) {
        debugPrint('[video] GET $videoUrl -> ${response.statusCode}');
      }
      if (response.statusCode != 200) return null;
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
