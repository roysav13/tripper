import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/sharing/tiktok_oembed_service.dart';
import 'package:tripper/features/places/data/tiktok_thumbnail_service.dart';
import 'package:tripper/features/places/presentation/tiktok_cover_capture_screen.dart';
import 'package:tripper/features/vault/data/document_ocr_service.dart';
import 'package:tripper/l10n/app_localizations.dart';

class _FakeOEmbedFetcher implements TikTokOEmbedFetcher {
  _FakeOEmbedFetcher(this.result);
  final TikTokOEmbed? result;

  @override
  Future<TikTokOEmbed?> fetch(String sharedText) async => result;
}

class _FakeThumbnailDownloader implements TikTokThumbnailDownloader {
  _FakeThumbnailDownloader(this.result);
  final String? result;

  @override
  Future<String?> download(String thumbnailUrl) async => result;
}

class _FakeRecognizer implements DocumentTextRecognizer {
  _FakeRecognizer(this.result);
  final String result;

  @override
  Future<String> extractText(String imagePath) async => result;
}

/// `_Stage.fetching` shows an indeterminate `CircularProgressIndicator`,
/// which schedules frames forever and so never lets `pumpAndSettle()`
/// settle — same well-known Flutter-test limitation the original
/// video-scrub screen's tests worked around. This drains the async
/// `_fetch()` chain with a bounded number of pumps instead.
Future<void> _pumpUntilFetched(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Widget _app({
  required TikTokOEmbedFetcher oembed,
  required TikTokThumbnailDownloader downloader,
  required DocumentTextRecognizer recognizer,
  required String sharedText,
  required Future<String?> Function(BuildContext) onOpen,
}) {
  return ProviderScope(
    overrides: [
      tiktokOEmbedFetcherProvider.overrideWithValue(oembed),
      tiktokThumbnailDownloaderProvider.overrideWithValue(downloader),
      documentTextRecognizerProvider.overrideWithValue(recognizer),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => onOpen(context),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('oEmbed fetch failure (no thumbnail) shows the error state',
      (tester) async {
    await tester.pumpWidget(_app(
      oembed: _FakeOEmbedFetcher(null),
      downloader: _FakeThumbnailDownloader(null),
      recognizer: _FakeRecognizer(''),
      sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
      onOpen: (context) => TikTokCoverCaptureScreen.open(
        context,
        sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
      ),
    ),
    );
    await tester.tap(find.text('open'));
    await _pumpUntilFetched(tester);

    expect(find.text("Couldn't fetch this video"), findsOneWidget);
  });

  testWidgets('thumbnail download failure shows the error state',
      (tester) async {
    await tester.pumpWidget(_app(
      oembed: _FakeOEmbedFetcher(
        const TikTokOEmbed(thumbnailUrl: 'https://example.com/t.jpg'),
      ),
      downloader: _FakeThumbnailDownloader(null),
      recognizer: _FakeRecognizer(''),
      sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
      onOpen: (context) => TikTokCoverCaptureScreen.open(
        context,
        sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
      ),
    ),
    );
    await tester.tap(find.text('open'));
    await _pumpUntilFetched(tester);

    expect(find.text("Couldn't fetch this video"), findsOneWidget);
  });

  testWidgets('OCR text pre-fills the editable field when found',
      (tester) async {
    await tester.pumpWidget(_app(
      oembed: _FakeOEmbedFetcher(
        const TikTokOEmbed(
          caption: 'A caption that should be ignored',
          thumbnailUrl: 'https://example.com/t.jpg',
        ),
      ),
      downloader: _FakeThumbnailDownloader('/tmp/thumb.jpg'),
      recognizer: _FakeRecognizer('Railay Beach'),
      sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
      onOpen: (context) => TikTokCoverCaptureScreen.open(
        context,
        sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
      ),
    ),
    );
    await tester.tap(find.text('open'));
    await _pumpUntilFetched(tester);

    expect(find.widgetWithText(TextField, 'Railay Beach'), findsOneWidget);
  });

  testWidgets('falls back to the caption when OCR finds nothing',
      (tester) async {
    await tester.pumpWidget(_app(
      oembed: _FakeOEmbedFetcher(
        const TikTokOEmbed(
          caption: 'East Java hidden gems #eastjava',
          thumbnailUrl: 'https://example.com/t.jpg',
        ),
      ),
      downloader: _FakeThumbnailDownloader('/tmp/thumb.jpg'),
      recognizer: _FakeRecognizer(''),
      sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
      onOpen: (context) => TikTokCoverCaptureScreen.open(
        context,
        sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
      ),
    ),
    );
    await tester.tap(find.text('open'));
    await _pumpUntilFetched(tester);

    expect(
      find.widgetWithText(TextField, 'East Java hidden gems #eastjava'),
      findsOneWidget,
    );
  });

  testWidgets(
      'no OCR text and no caption shows the empty-text hint, field stays '
      'editable', (tester) async {
    await tester.pumpWidget(_app(
      oembed: _FakeOEmbedFetcher(
        const TikTokOEmbed(thumbnailUrl: 'https://example.com/t.jpg'),
      ),
      downloader: _FakeThumbnailDownloader('/tmp/thumb.jpg'),
      recognizer: _FakeRecognizer(''),
      sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
      onOpen: (context) => TikTokCoverCaptureScreen.open(
        context,
        sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
      ),
    ),
    );
    await tester.tap(find.text('open'));
    await _pumpUntilFetched(tester);

    expect(
      find.text('No text found in this frame — you can type it in'),
      findsOneWidget,
    );
  });

  testWidgets('tapping "Look up" returns the edited text to the caller',
      (tester) async {
    String? result;
    await tester.pumpWidget(_app(
      oembed: _FakeOEmbedFetcher(
        const TikTokOEmbed(thumbnailUrl: 'https://example.com/t.jpg'),
      ),
      downloader: _FakeThumbnailDownloader('/tmp/thumb.jpg'),
      recognizer: _FakeRecognizer('Railay Beach'),
      sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
      onOpen: (context) async {
        result = await TikTokCoverCaptureScreen.open(
          context,
          sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
        );
        return result;
      },
    ),
    );
    await tester.tap(find.text('open'));
    await _pumpUntilFetched(tester);

    await tester.enterText(find.byType(TextField), 'Railay Beach Viewpoint');
    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();

    expect(result, 'Railay Beach Viewpoint');
  });

  testWidgets('tapping Cancel on the review screen returns null',
      (tester) async {
    String? result = 'not-yet-set';
    await tester.pumpWidget(_app(
      oembed: _FakeOEmbedFetcher(
        const TikTokOEmbed(thumbnailUrl: 'https://example.com/t.jpg'),
      ),
      downloader: _FakeThumbnailDownloader('/tmp/thumb.jpg'),
      recognizer: _FakeRecognizer('Railay Beach'),
      sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
      onOpen: (context) async {
        result = await TikTokCoverCaptureScreen.open(
          context,
          sharedText: 'https://vt.tiktok.com/ZS6abcDEF/',
        );
        return result;
      },
    ),
    );
    await tester.tap(find.text('open'));
    await _pumpUntilFetched(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
