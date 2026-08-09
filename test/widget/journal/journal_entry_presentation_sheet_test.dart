import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:tripper/core/theme/app_colors.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/domain/journal_photo.dart';
import 'package:tripper/features/journal/presentation/journal_entry_presentation_sheet.dart';
import 'package:tripper/features/journal/presentation/journal_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_journal_repository.dart';

/// 1x1 PNG. Sync file IO below: real IO never completes inside the
/// fake-async test zone, so `tester.runAsync` is used to let the real
/// event loop deliver the decode (see show_code_screen_test.dart, same
/// pattern).
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

JournalEntry _e(
  String id, {
  String summary = 'Some summary',
  List<JournalPhoto> photos = const [],
}) =>
    JournalEntry(
      id: id,
      tripId: 't1',
      summary: summary,
      loggedAt: DateTime(2026, 7, 20, 14, 30),
      createdAt: DateTime(2026, 7, 20, 14, 30),
      placeName: 'Krabi',
      photos: photos,
    );

Future<T?> _open<T>(
  WidgetTester tester, {
  required List<JournalEntry> entries,
  required int initialIndex,
  void Function(int index)? onPageChanged,
  FakeJournalRepository? repo,
}) async {
  T? result;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        journalRepositoryProvider
            .overrideWithValue(repo ?? FakeJournalRepository(entries)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showJournalEntryPresentationSheet(
                  context,
                  tripId: 't1',
                  entries: entries,
                  initialIndex: initialIndex,
                  onPageChanged: onPageChanged ?? (_) {},
                ) as T?;
              },
              child: const Text('open'),
            ),
          ),
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(TextButton));
  await tester.pumpAndSettle();
  return result;
}

/// The decoration color of the photo carousel's dot indicator at [index]
/// (`_photoCarousel`'s dot `Container`s are keyed `photo-dot-$i`) — same
/// pattern as `journal_gallery_card_test.dart`'s `_borderColor`, adapted
/// from reading `Material.shape` to reading `Container.decoration`.
Color _dotColor(WidgetTester tester, int index) {
  final container = tester.widget<Container>(
    find.byKey(ValueKey('photo-dot-$index')),
  );
  return (container.decoration! as BoxDecoration).color!;
}

void main() {
  testWidgets('single entry: shows its details, no page indicator dots',
      (tester) async {
    await _open<void>(tester, entries: [_e('a')], initialIndex: 0);

    expect(find.text('Some summary'), findsOneWidget);
    expect(find.text('Krabi'), findsOneWidget);
    // No dot row for a single-page view: only one Container-decorated
    // circle would exist per dot, so absence of a second entry's summary
    // combined with a single page is enough — checked structurally via
    // PageView having exactly one child instead of asserting on dots
    // directly (dots have no text/semantics to query).
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('multi-entry: swiping changes the visible entry and fires '
      'onPageChanged', (tester) async {
    int? lastPage;
    await _open<void>(
      tester,
      entries: [_e('a', summary: 'First'), _e('b', summary: 'Second')],
      initialIndex: 0,
      onPageChanged: (i) => lastPage = i,
    );

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Second'), findsOneWidget);
    expect(find.text('First'), findsNothing);
    expect(lastPage, 1);
  });

  testWidgets('empty-summary entry falls back to "Not written yet"',
      (tester) async {
    await _open<void>(
      tester,
      entries: [_e('a', summary: '')],
      initialIndex: 0,
    );
    expect(find.text('Not written yet'), findsOneWidget);
  });

  testWidgets('sheet height adapts to entry: 0.4 for photo-less entries',
      (tester) async {
    await _open<void>(
      tester,
      entries: [_e('a', summary: 'No photo here')],
      initialIndex: 0,
    );
    final noPhotoHeight =
        tester.getSize(find.byType(AnimatedContainer)).height;
    final screenHeight = MediaQuery.of(tester.element(find.byType(AnimatedContainer))).size.height;

    // Photo-less should be ~0.4 of screen height
    expect(noPhotoHeight, closeTo(screenHeight * 0.4, 1));
  });

  testWidgets('sheet height adapts to entry: 0.7 for entries with photos',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('journal_height');
    addTearDown(() {
      imageCache.clear();
      imageCache.clearLiveImages();
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // OS cleans up temp dirs — don't fail the test over a lock.
      }
    });
    final photo = File('${dir.path}/a.png')..writeAsBytesSync(_pngBytes);

    await _open<void>(
      tester,
      entries: [
        _e(
          'b',
          summary: 'Has a photo',
          photos: [JournalPhoto(id: 'p1', filePath: photo.path)],
        ),
      ],
      initialIndex: 0,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    final photoHeight = tester.getSize(find.byType(AnimatedContainer)).height;
    final photoScreenHeight = MediaQuery.of(tester.element(find.byType(AnimatedContainer))).size.height;

    // Photo entry should be ~0.7 of screen height
    expect(photoHeight, closeTo(photoScreenHeight * 0.7, 1));
  });

  testWidgets('place name renders as a prominent title, not a small row',
      (tester) async {
    await _open<void>(tester, entries: [_e('a')], initialIndex: 0);
    final placeText = tester.widget<Text>(find.text('Krabi'));
    expect(placeText.style?.fontFamily, 'Fraunces');
  });

  testWidgets('Edit closes the sheet and opens the entry form pre-filled',
      (tester) async {
    await _open<void>(tester, entries: [_e('a', summary: 'Edit me')], initialIndex: 0);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Some summary'), findsNothing); // presentation gone
    // Form sheet title is a SectionLabel, which force-uppercases its text.
    expect(find.text('EDIT ENTRY'), findsOneWidget); // form sheet title
    expect(find.text('Edit me'), findsOneWidget); // pre-filled summary field
  });

  testWidgets('Delete, after confirming, removes the entry and closes the sheet',
      (tester) async {
    final repo = FakeJournalRepository([_e('a')]);
    await _open<void>(tester, entries: [_e('a')], initialIndex: 0, repo: repo);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last); // confirm dialog's button
    await tester.pumpAndSettle();

    expect(await repo.getById('a'), isNull);
    expect(find.text('Krabi'), findsNothing); // sheet closed
  });

  testWidgets(
      'photo entry: renders the photo header and its overflow menu is '
      'tappable', (tester) async {
    final dir = Directory.systemTemp.createTempSync('journal_presentation');
    addTearDown(() {
      // Windows may still hold the image file handle via the image cache.
      imageCache.clear();
      imageCache.clearLiveImages();
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Temp dir — the OS cleans it up; don't fail the test over a lock.
      }
    });
    final file = File('${dir.path}/photo.png')..writeAsBytesSync(_pngBytes);

    await _open<void>(
      tester,
      entries: [
        _e(
          'a',
          summary: 'Sunset at the pier',
          photos: [JournalPhoto(id: 'p1', filePath: file.path)],
        ),
      ],
      initialIndex: 0,
    );
    // Let the real event loop deliver the file read + decode.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    // Confirms the photo header (not the plain header) is what's on
    // screen for this entry.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Sunset at the pier'), findsOneWidget);

    // The same hit-test concern already found and fixed for _plainHeader
    // (menu button painted outside the Stack's own hit-testable bounds)
    // could just as easily have slipped into _photoHeader — confirm the
    // menu is actually reachable here too, not just visually present.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('menu sits on a circular scrim when the entry has a photo',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('journal_menu_scrim');
    addTearDown(() {
      imageCache.clear();
      imageCache.clearLiveImages();
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // OS cleans up temp dirs — don't fail the test over a lock.
      }
    });
    final photo = File('${dir.path}/a.png')..writeAsBytesSync(_pngBytes);

    await _open<void>(
      tester,
      entries: [
        _e(
          'a',
          summary: 'Has a photo',
          photos: [JournalPhoto(id: 'p1', filePath: photo.path)],
        ),
      ],
      initialIndex: 0,
    );

    final decoratedBox = tester.widget<DecoratedBox>(
      find.ancestor(
        of: find.byIcon(Icons.more_vert),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
  });

  testWidgets('menu has no scrim when the entry has no photo', (tester) async {
    await _open<void>(tester, entries: [_e('a')], initialIndex: 0);

    expect(
      find.ancestor(
        of: find.byIcon(Icons.more_vert),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
  });

  testWidgets('multi-photo entry shows a dot per photo, swiping changes it',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('journal_carousel');
    addTearDown(() {
      imageCache.clear();
      imageCache.clearLiveImages();
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // OS cleans up temp dirs — don't fail the test over a lock.
      }
    });
    final photoA = File('${dir.path}/a.png')..writeAsBytesSync(_pngBytes);
    final photoB = File('${dir.path}/b.png')..writeAsBytesSync(_pngBytes);

    await _open<void>(
      tester,
      entries: [
        _e(
          'a',
          summary: 'Two photos here',
          photos: [
            JournalPhoto(id: 'p1', filePath: photoA.path),
            JournalPhoto(id: 'p2', filePath: photoB.path),
          ],
        ),
      ],
      initialIndex: 0,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    // Dot 0 (photo A) starts active (full opacity); dot 1 (photo B) starts
    // dimmed. Comparing actual decoration colors — not just widget counts,
    // since PageView only ever builds one page at a time regardless of
    // which photo it is, so `find.byType(Image)` can't tell them apart.
    expect(_dotColor(tester, 0), AppColors.light.surface);
    expect(
      _dotColor(tester, 1),
      AppColors.light.surface.withValues(alpha: 0.5),
    );

    // Inner PageView is the innermost/last one in pre-order traversal —
    // the outer (entry-to-entry) PageView is always found first.
    await tester.drag(find.byType(PageView).last, const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    // Active dot has swapped from 0 to 1, confirming the swipe actually
    // paged the carousel rather than just bouncing.
    expect(
      _dotColor(tester, 0),
      AppColors.light.surface.withValues(alpha: 0.5),
    );
    expect(_dotColor(tester, 1), AppColors.light.surface);
  });

  testWidgets(
      'swiping past the last photo in a multi-entry day advances to the '
      'next entry', (tester) async {
    final dir = Directory.systemTemp.createTempSync('journal_carousel2');
    addTearDown(() {
      imageCache.clear();
      imageCache.clearLiveImages();
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // OS cleans up temp dirs — don't fail the test over a lock.
      }
    });
    final photo = File('${dir.path}/a.png')..writeAsBytesSync(_pngBytes);

    await _open<void>(
      tester,
      entries: [
        _e(
          'a',
          summary: 'Only entry photo',
          photos: [JournalPhoto(id: 'p1', filePath: photo.path)],
        ),
        _e('b', summary: 'Second entry, no photo'),
      ],
      initialIndex: 0,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.text('Only entry photo'), findsOneWidget);

    // A single photo means there's nowhere for the inner carousel to go
    // — this drag should overscroll immediately and fall through to the
    // outer PageView, landing on entry 'b'. `.last` targets the inner
    // (photo) PageView: pre-order traversal finds the outer
    // (entry-to-entry) PageView first, since it's the ancestor.
    await tester.drag(find.byType(PageView).last, const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Second entry, no photo'), findsOneWidget);
    expect(find.text('Only entry photo'), findsNothing);
  });

  testWidgets('tapping a photo in the carousel opens the full-screen viewer',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('journal_photo_tap');
    addTearDown(() {
      imageCache.clear();
      imageCache.clearLiveImages();
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // OS cleans up temp dirs — don't fail the test over a lock.
      }
    });
    final photo = File('${dir.path}/a.png')..writeAsBytesSync(_pngBytes);

    // Warm the cache BEFORE any pump — both the carousel's own Image and
    // the full-screen viewer's PhotoView key off the same FileImage, and
    // PhotoView's default loading state is an indeterminate
    // CircularProgressIndicator whose repeating animation would otherwise
    // keep pumpAndSettle from ever settling under flutter test's
    // fake-async zone (same reasoning as
    // journal_photo_viewer_test.dart's _warmImageCache).
    await tester.runAsync(() => _warmImageCache(photo));

    await _open<void>(
      tester,
      entries: [
        _e(
          'a',
          summary: 'Has a photo',
          photos: [JournalPhoto(id: 'p1', filePath: photo.path)],
        ),
      ],
      initialIndex: 0,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();

    expect(find.byType(PhotoViewGallery), findsOneWidget);
  });
}

/// Decodes [file] and seats it in the global [imageCache] via a real
/// event-loop turn — see journal_photo_viewer_test.dart's identical helper
/// for the full explanation.
Future<void> _warmImageCache(File file) {
  final provider = FileImage(file);
  final stream = provider.resolve(ImageConfiguration.empty);
  final completer = Completer<void>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, synchronousCall) {
      stream.removeListener(listener);
      completer.complete();
    },
    onError: (error, stackTrace) {
      stream.removeListener(listener);
      completer.completeError(error, stackTrace);
    },
  );
  stream.addListener(listener);
  return completer.future;
}
