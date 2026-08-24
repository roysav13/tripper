import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/scratch_file.dart';
import '../../../core/sharing/tiktok_oembed_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/local_images.dart';
import '../../../l10n/app_localizations.dart';
import '../../vault/data/document_ocr_service.dart';
import '../data/tiktok_thumbnail_service.dart';

/// Fetch a TikTok's public caption + cover image (oEmbed, no video
/// download) → OCR the cover image → editable review, falling back to the
/// caption text if OCR found nothing. Returns the confirmed text, or null
/// if the user backs out. Pushed the same way `AddPlaceScreen` is
/// (`Navigator...push`, fullscreen dialog) — no named route, matching the
/// existing pattern.
///
/// This replaced an earlier design that downloaded and let the user scrub
/// the actual video: TikTok's video-playback CDN is behind Akamai Bot
/// Manager, which blocked every request regardless of headers sent
/// (confirmed on-device across several attempts). The oEmbed endpoint and
/// its thumbnail images are meant for arbitrary third-party fetching and
/// carry no such protection.
class TikTokCoverCaptureScreen extends ConsumerStatefulWidget {
  const TikTokCoverCaptureScreen({super.key, required this.sharedText});

  final String sharedText;

  static Future<String?> open(
    BuildContext context, {
    required String sharedText,
  }) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => TikTokCoverCaptureScreen(sharedText: sharedText),
      ),
    );
  }

  @override
  ConsumerState<TikTokCoverCaptureScreen> createState() =>
      TikTokCoverCaptureScreenState();
}

enum _Stage { fetching, fetchFailed, reviewingText }

class TikTokCoverCaptureScreenState
    extends ConsumerState<TikTokCoverCaptureScreen> {
  _Stage _stage = _Stage.fetching;
  String? _thumbnailPath;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _textController.dispose();
    // The downloaded thumbnail exists only for this screen's lifetime.
    // dispose() can't await, so this is fire-and-forget — best-effort,
    // same contract as document_ocr_service.dart's per-page cleanup.
    final thumbnailPath = _thumbnailPath;
    if (thumbnailPath != null) unawaited(deleteScratchFile(thumbnailPath));
    super.dispose();
  }

  Future<void> _fetch() async {
    final oembed =
        await ref.read(tiktokOEmbedFetcherProvider).fetch(widget.sharedText);
    final thumbnailUrl = oembed?.thumbnailUrl;
    if (thumbnailUrl == null) {
      if (mounted) setState(() => _stage = _Stage.fetchFailed);
      return;
    }
    final thumbnailPath = await ref
        .read(tiktokThumbnailDownloaderProvider)
        .download(thumbnailUrl);
    if (thumbnailPath == null) {
      if (mounted) setState(() => _stage = _Stage.fetchFailed);
      return;
    }
    final ocrText = await ref
        .read(documentTextRecognizerProvider)
        .extractText(thumbnailPath);
    if (!mounted) return;
    // The cover frame is a best-effort OCR target — it's the video's first
    // frame, which may or may not carry the on-screen text a mid-video
    // frame would. The caption frequently names the place directly too
    // (real example seen on-device: "...East Java turned out to be one of
    // those places...#eastjava"), so it's a reasonable fallback rather
    // than leaving the field empty when OCR finds nothing.
    final prefill =
        ocrText.trim().isNotEmpty ? ocrText : (oembed?.caption ?? '');
    _textController.text = prefill;
    setState(() {
      _thumbnailPath = thumbnailPath;
      _stage = _Stage.reviewingText;
    });
  }

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
        _Stage.reviewingText => Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_thumbnailPath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image(
                      image: pickedFileImage(_thumbnailPath!),
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                if (_textController.text.trim().isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          MaterialLocalizations.of(context).cancelButtonLabel,
                        ),
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
