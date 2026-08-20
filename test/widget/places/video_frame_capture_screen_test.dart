import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/sharing/tiktok_video_link_service.dart';
import 'package:tripper/features/places/data/video_capture_service.dart';
import 'package:tripper/features/places/presentation/video_frame_capture_screen.dart';
import 'package:tripper/features/vault/data/document_ocr_service.dart';
import 'package:tripper/l10n/app_localizations.dart';

class _FakeRecognizer implements DocumentTextRecognizer {
  _FakeRecognizer(this.result);
  final String result;

  @override
  Future<String> extractText(String imagePath) async => result;
}

class _FakeCapturer implements VideoFrameCapturer {
  _FakeCapturer(this.result);
  final String? result;

  @override
  Future<String?> captureFrame(String videoPath, Duration position) async =>
      result;
}

class _FailingDownloader implements VideoDownloader {
  @override
  Future<String?> download(Uri videoUrl) async => null;
}

class _FakeDownloader implements VideoDownloader {
  @override
  Future<String?> download(Uri videoUrl) async => '/tmp/fake_video.mp4';
}

/// Stands in for the real, network-touching `TikTokVideoLinkService` in
/// every test below — resolves to a fixed URL, so these tests exercise the
/// downloader/capturer/OCR chain without ever reaching the network
/// (CLAUDE.md hard rule 5).
class _FakeTikTokVideoLinkService implements TikTokVideoLinkService {
  @override
  Future<Uri?> resolveVideoUrl(String sharedText) async =>
      Uri.parse('https://cdn.example.com/video.mp4');
}

/// `pumpAndSettle()` can't be used right after opening the screen:
/// `_Stage.fetching` shows an indeterminate `CircularProgressIndicator`,
/// which schedules frames forever in the widget-test VM and so never lets
/// pumpAndSettle settle until the async `_fetch()` chain has moved the
/// screen off that stage. This drains that chain (two sequential awaits,
/// plus the player's `initialize()`) with a bounded number of pumps
/// instead.
///
/// Note the player never actually initializes here — `video_player` has no
/// platform implementation registered in the test VM, so `initialize()`
/// throws and the screen lands on its "couldn't fetch this video" state
/// rather than on a live scrub bar. That's why the capture tests below
/// reach `debugCapture()` directly instead of tapping the real button; the
/// scrub/play/pause controls are verified on-device.
Future<void> _pumpUntilFetched(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Widget _app({
  required VideoDownloader downloader,
  required VideoFrameCapturer capturer,
  required DocumentTextRecognizer recognizer,
  required String sharedText,
}) {
  final navigatorKey = GlobalKey<NavigatorState>();
  return ProviderScope(
    overrides: [
      tikTokVideoLinkServiceProvider
          .overrideWithValue(_FakeTikTokVideoLinkService()),
      videoDownloaderProvider.overrideWithValue(downloader),
      videoFrameCapturerProvider.overrideWithValue(capturer),
      documentTextRecognizerProvider.overrideWithValue(recognizer),
    ],
    child: MaterialApp(
      navigatorKey: navigatorKey,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () =>
              VideoFrameCaptureScreen.open(context, sharedText: sharedText),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('video fetch failure shows the error state, never a hang',
      (tester) async {
    await tester.pumpWidget(
      _app(
        downloader: _FailingDownloader(),
        capturer: _FakeCapturer(null),
        recognizer: _FakeRecognizer(''),
        sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't fetch this video"), findsOneWidget);
  });

  testWidgets(
      'captured frame with recognized text pre-fills an editable field',
      (tester) async {
    await tester.pumpWidget(
      _app(
        downloader: _FakeDownloader(),
        capturer: _FakeCapturer('/tmp/frame.png'),
        recognizer: _FakeRecognizer('Railay Beach'),
        sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
      ),
    );
    await tester.tap(find.text('open'));
    await _pumpUntilFetched(tester);

    // Debug-only test hook (Step 3) stands in for tapping "Capture" on the
    // real (untestable in-VM) video player.
    final state = tester.state<VideoFrameCaptureScreenState>(
      find.byType(VideoFrameCaptureScreen),
    );
    await state.debugCapture();
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Railay Beach'), findsOneWidget);
  });

  testWidgets('failed frame capture says so instead of silently doing nothing',
      (tester) async {
    await tester.pumpWidget(
      _app(
        downloader: _FakeDownloader(),
        capturer: _FakeCapturer(null),
        recognizer: _FakeRecognizer('should not be called'),
        sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
      ),
    );
    await tester.tap(find.text('open'));
    await _pumpUntilFetched(tester);

    final state = tester.state<VideoFrameCaptureScreenState>(
      find.byType(VideoFrameCaptureScreen),
    );
    await state.debugCapture();
    // Two pumps: one to run the frame that inserts the SnackBar, one to
    // start its entry animation. Not `pumpAndSettle()` — that would run
    // out the SnackBar's own 4s dismiss timer and remove it again.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text("Couldn't capture that frame — try again"),
      findsOneWidget,
    );
    // Never advanced to the review stage — the capture is still re-triable.
    expect(find.text('Recognized text'), findsNothing);
  });

  testWidgets('no text recognized shows the empty-text hint, field stays '
      'editable', (tester) async {
    await tester.pumpWidget(
      _app(
        downloader: _FakeDownloader(),
        capturer: _FakeCapturer('/tmp/frame.png'),
        recognizer: _FakeRecognizer(''),
        sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
      ),
    );
    await tester.tap(find.text('open'));
    await _pumpUntilFetched(tester);

    final state = tester.state<VideoFrameCaptureScreenState>(
      find.byType(VideoFrameCaptureScreen),
    );
    await state.debugCapture();
    await tester.pumpAndSettle();

    expect(
      find.text('No text found in this frame — you can type it in'),
      findsOneWidget,
    );
  });

  testWidgets('tapping "Look up" returns the edited text to the caller',
      (tester) async {
    late final Future<String?> result;
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tikTokVideoLinkServiceProvider
              .overrideWithValue(_FakeTikTokVideoLinkService()),
          videoDownloaderProvider.overrideWithValue(_FakeDownloader()),
          videoFrameCapturerProvider
              .overrideWithValue(_FakeCapturer('/tmp/frame.png')),
          documentTextRecognizerProvider
              .overrideWithValue(_FakeRecognizer('Railay Beach')),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                result = VideoFrameCaptureScreen.open(
                  context,
                  sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _pumpUntilFetched(tester);
    final state = tester.state<VideoFrameCaptureScreenState>(
      find.byType(VideoFrameCaptureScreen),
    );
    await state.debugCapture();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Railay Beach Viewpoint');
    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();

    expect(await result, 'Railay Beach Viewpoint');
  });
}
