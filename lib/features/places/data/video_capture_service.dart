import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Downloads a resolved TikTok video URL to a temp file. Seam for
/// testability, same pattern as `DocumentTextRecognizer`/
/// `PdfPageRasterizer` — nothing outside this file touches `http` for
/// video bytes.
abstract interface class VideoDownloader {
  /// Temp file path, or null on any failure (offline, non-200, timeout).
  /// Caller owns cleanup of the returned file.
  Future<String?> download(Uri videoUrl);
}

class HttpVideoDownloader implements VideoDownloader {
  HttpVideoDownloader(this._client);

  final http.Client _client;

  @override
  Future<String?> download(Uri videoUrl) async {
    try {
      final response =
          await _client.get(videoUrl).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
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

final videoDownloaderProvider =
    Provider<VideoDownloader>((ref) => HttpVideoDownloader(http.Client()));

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
