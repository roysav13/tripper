import 'dart:async';
import 'dart:io';

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
    // The downloaded video exists only for this screen's lifetime (design
    // spec: the video is held "only transiently until OCR runs"). dispose()
    // can't await, so this is fire-and-forget — best-effort, same as the
    // frame cleanup in `_capture()`.
    final videoPath = _videoPath;
    if (videoPath != null) unawaited(_deleteQuietly(videoPath));
    super.dispose();
  }

  /// Best-effort temp cleanup — a leftover temp file is harmless, a crash
  /// over one would not be (same contract as `DocumentTextExtractor`'s
  /// per-page cleanup in `document_ocr_service.dart`).
  Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
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
    unawaited(
      controller.initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {
        // A file that downloaded fine but won't decode is, from the user's
        // side, the same dead end as a download that never arrived — so it
        // reuses `fetchFailed`'s visible "couldn't fetch this video" +
        // cancel UI rather than leaving the spinner turning forever
        // (CLAUDE.md hard rule 4). Guarded on the stage so a late failure
        // can't yank the user back out of a review they already reached.
        if (mounted && _stage == _Stage.scrubbing) {
          setState(() => _stage = _Stage.fetchFailed);
        }
      }),
    );
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
    if (framePath == null) {
      // Stays on the scrub screen, re-triable — but says so out loud
      // instead of swallowing the tap (CLAUDE.md hard rule 4).
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.videoCaptureFrameFailed)),
      );
      return;
    }
    final text =
        await ref.read(documentTextRecognizerProvider).extractText(framePath);
    // The frame PNG existed only to be read by OCR, which has now happened,
    // so nothing downstream waits on the unlink — fire-and-forget keeps the
    // review screen from waiting on a filesystem round-trip (and keeps real
    // I/O off the await path, which a widget test's fake-async zone can't
    // drive to completion).
    unawaited(_deleteQuietly(framePath));
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
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  ),
                ],
              ),
            ),
          ),
        _Stage.scrubbing => _ScrubStage(
            controller: _controller,
            onCapture: _capture,
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

/// The scrub stage: the video, a draggable progress bar, a play/pause
/// toggle, and "Capture this frame". Without the bar and the toggle every
/// capture would grab position zero — the whole premise of the feature is
/// pausing where the on-screen text is legible and grabbing *that* frame.
///
/// [VideoPlayerController] is a [ChangeNotifier], so the controls listen to
/// it directly ([AnimatedBuilder]) rather than reacting only to their own
/// taps: that keeps the icon honest when playback state changes for reasons
/// this widget didn't cause — a scrub-bar drag, reaching the end of the
/// clip — which is how `video_player`'s own example wires its controls.
class _ScrubStage extends StatelessWidget {
  const _ScrubStage({required this.controller, required this.onCapture});

  final VideoPlayerController? controller;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = this.controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // A progress bar needs a real duration and the player a real
        // texture, so both wait on the same `isInitialized` guard the
        // video itself already used.
        final ready = controller.value.isInitialized;
        return Column(
          children: [
            Expanded(
              child: ready
                  ? VideoPlayer(controller)
                  : const Center(child: CircularProgressIndicator()),
            ),
            if (ready) ...[
              VideoProgressIndicator(controller, allowScrubbing: true),
              IconButton(
                iconSize: 36,
                icon: Icon(
                  controller.value.isPlaying
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                ),
                onPressed: () {
                  if (controller.value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                },
              ),
            ],
            Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: FilledButton(
                onPressed: onCapture,
                child: Text(l10n.videoCaptureButton),
              ),
            ),
          ],
        );
      },
    );
  }
}
