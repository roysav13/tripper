import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/sharing/tiktok_video_link_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../vault/data/document_ocr_service.dart';
import '../data/video_capture_service.dart';

/// Fetch → scrub/pause → capture a frame → OCR it → editable review, per
/// design spec §4-5.4/5.5. Returns the confirmed text, or null if the
/// user backs out anywhere along the way. Pushed the same way
/// `AddPlaceScreen` is (`Navigator...push`, fullscreen dialog) — no named
/// route, matching the existing pattern.
class VideoFrameCaptureScreen extends ConsumerStatefulWidget {
  const VideoFrameCaptureScreen({super.key, required this.sharedText});

  final String sharedText;

  static Future<String?> open(
    BuildContext context, {
    required String sharedText,
  }) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            VideoFrameCaptureScreen(sharedText: sharedText),
      ),
    );
  }

  @override
  ConsumerState<VideoFrameCaptureScreen> createState() =>
      VideoFrameCaptureScreenState();
}

enum _Stage { fetching, fetchFailed, scrubbing, reviewingText }

class VideoFrameCaptureScreenState
    extends ConsumerState<VideoFrameCaptureScreen> {
  _Stage _stage = _Stage.fetching;
  String? _videoPath;
  VideoPlayerController? _controller;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final videoUrl = await ref
        .read(tikTokVideoLinkServiceProvider)
        .resolveVideoUrl(widget.sharedText);
    if (videoUrl == null) {
      if (mounted) setState(() => _stage = _Stage.fetchFailed);
      return;
    }
    final path = await ref.read(videoDownloaderProvider).download(videoUrl);
    if (path == null) {
      if (mounted) setState(() => _stage = _Stage.fetchFailed);
      return;
    }
    if (!mounted) return;
    final controller = VideoPlayerController.file(File(path));
    setState(() {
      _videoPath = path;
      _stage = _Stage.scrubbing;
      _controller = controller;
    });
    // Not awaited into the setState above — initialization can be slow,
    // and the scrub screen already shows a spinner via the
    // `isInitialized` check in build() until this resolves.
    controller.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {
      // Degrades to the same "spinner never resolves past this point"
      // state a real playback failure would show — on-device only, not
      // exercised by widget tests (see this task's testability note).
    });
  }

  Future<void> _capture() async {
    final path = _videoPath;
    if (path == null) return;
    final position = _controller?.value.position ?? Duration.zero;
    final framePath =
        await ref.read(videoFrameCapturerProvider).captureFrame(
              path,
              position,
            );
    if (framePath == null) return; // stays on the scrub screen, re-triable
    final text =
        await ref.read(documentTextRecognizerProvider).extractText(framePath);
    if (!mounted) return;
    _textController.text = text;
    setState(() => _stage = _Stage.reviewingText);
  }

  /// Test-only hook standing in for a real "Capture" tap — `video_player`
  /// cannot initialize inside the widget-test VM, so tests reach this
  /// directly instead of pumping a real player. See Task 7's testability
  /// note.
  @visibleForTesting
  Future<void> debugCapture() => _capture();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.videoCaptureTitle)),
      body: switch (_stage) {
        _Stage.fetching => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.videoCaptureFetching),
              ],
            ),
          ),
        _Stage.fetchFailed => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.videoCaptureFetchFailedTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.videoCaptureFetchFailedBody,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(MaterialLocalizations.of(context)
                        .cancelButtonLabel),
                  ),
                ],
              ),
            ),
          ),
        _Stage.scrubbing => Column(
            children: [
              Expanded(
                child: _controller != null &&
                        _controller!.value.isInitialized
                    ? VideoPlayer(_controller!)
                    : const Center(child: CircularProgressIndicator()),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FilledButton(
                  onPressed: _capture,
                  child: Text(l10n.videoCaptureButton),
                ),
              ),
            ],
          ),
        _Stage.reviewingText => Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_textController.text.trim().isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(l10n.videoCaptureNoTextFound),
                  ),
                TextField(
                  controller: _textController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.videoCaptureRecognizedLabel,
                    helperText: l10n.videoCaptureRecognizedHint,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            setState(() => _stage = _Stage.scrubbing),
                        child: Text(l10n.videoCaptureRecapture),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: _textController.text.trim().isEmpty
                            ? null
                            : () => Navigator.of(context)
                                .pop(_textController.text.trim()),
                        child: Text(l10n.videoCaptureLookUp),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      },
    );
  }
}
