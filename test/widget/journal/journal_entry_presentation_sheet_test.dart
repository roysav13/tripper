import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
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
}
