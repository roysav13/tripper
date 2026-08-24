import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/local_images.dart';
import 'package:tripper/core/widgets/paper_card.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/domain/journal_photo.dart';
import 'package:tripper/features/journal/presentation/journal_widgets.dart';
import 'package:tripper/l10n/app_localizations.dart';

JournalEntry _e(
  String id,
  DateTime loggedAt, {
  String? placeName,
  List<JournalPhoto> photos = const [],
}) =>
    JournalEntry(
      id: id,
      tripId: 't1',
      summary: 'summary for $id',
      loggedAt: loggedAt,
      createdAt: loggedAt,
      placeName: placeName,
      photos: photos,
    );

/// ProviderScope because the cards resolve photos through
/// `fileVaultServiceProvider` rather than `Image.file`.
Widget _wrap(Widget child, {double height = 200}) => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: SizedBox(height: height, child: child)),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );

void main() {
  testWidgets('single-entry day: tapping it reports that day with index 0',
      (tester) async {
    List<JournalEntry>? tappedDay;
    int? tappedIndex;
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: [_e('a', DateTime(2026, 7, 20), placeName: 'Krabi')],
          selectedEntryId: null,
          onTapDay: (day, index) {
            tappedDay = day;
            tappedIndex = index;
          },
          onCenteredDayChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Krabi'), findsOneWidget);
    await tester.tap(find.text('Krabi'));
    expect(tappedDay?.map((e) => e.id).toList(), ['a']);
    expect(tappedIndex, 0);
  });

  testWidgets(
      'multi-entry day shows a count badge, and a busy day (6 entries) '
      'does not overflow', (tester) async {
    final entries = [
      _e('morning', DateTime(2026, 7, 20, 9)),
      _e('brunch', DateTime(2026, 7, 20, 11)),
      _e('museum', DateTime(2026, 7, 20, 13)),
      _e('market', DateTime(2026, 7, 20, 16)),
      _e('dinner', DateTime(2026, 7, 20, 19)),
      _e('evening', DateTime(2026, 7, 20, 20)),
    ];
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: entries,
          selectedEntryId: null,
          onTapDay: (_, __) {},
          onCenteredDayChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a grouped card reports all six entries at index 0',
      (tester) async {
    List<JournalEntry>? tappedDay;
    int? tappedIndex;
    final entries = [
      _e('morning', DateTime(2026, 7, 20, 9)),
      _e('brunch', DateTime(2026, 7, 20, 11)),
      _e('museum', DateTime(2026, 7, 20, 13)),
      _e('market', DateTime(2026, 7, 20, 16)),
      _e('dinner', DateTime(2026, 7, 20, 19)),
      _e('evening', DateTime(2026, 7, 20, 20)),
    ];
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: entries,
          selectedEntryId: null,
          onTapDay: (day, index) {
            tappedDay = day;
            tappedIndex = index;
          },
          onCenteredDayChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('6'));
    expect(tappedDay?.length, 6);
    expect(tappedIndex, 0);
  });

  testWidgets(
      "a grouped card's cover photo is the day's latest entry with a "
      'photo, not the first one in list order', (tester) async {
    final entries = [
      // Deliberately out of chronological order in the input list, and
      // with the earliest entry (not the last) having a photo too — the
      // cover must still be 'evening', the latest, not 'morning', the
      // first-with-a-photo.
      _e(
        'morning',
        DateTime(2026, 7, 20, 9),
        photos: const [JournalPhoto(id: 'p-morning', filePath: '/tmp/a.jpg')],
      ),
      _e('brunch', DateTime(2026, 7, 20, 11)),
      _e(
        'evening',
        DateTime(2026, 7, 20, 20),
        photos: const [JournalPhoto(id: 'p-evening', filePath: '/tmp/b.jpg')],
      ),
    ];
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: entries,
          selectedEntryId: null,
          onTapDay: (_, __) {},
          onCenteredDayChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.byType(Image));
    final localImage = image.image as LocalFileImage;
    expect(localImage.storageKey, '/tmp/b.jpg');
  });

  testWidgets('entries on different days each get their own dot and card',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: [
            _e('day1', DateTime(2026, 7, 19), placeName: 'Krabi'),
            _e('day2', DateTime(2026, 7, 20), placeName: 'Phuket'),
          ],
          selectedEntryId: null,
          onTapDay: (_, __) {},
          onCenteredDayChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Krabi'), findsOneWidget);
    expect(find.text('Phuket'), findsOneWidget);
    expect(find.text('2'), findsNothing); // no grouping badge — two days
  });

  testWidgets('selecting an entry scrolls its day into view', (tester) async {
    final entries = [
      for (var i = 0; i < 20; i++)
        _e('e$i', DateTime(2026, 7, 1 + i), placeName: 'Place $i'),
    ];
    Widget build(String? selectedEntryId) => _wrap(
          JournalGalleryTimeline(
            entries: entries,
            selectedEntryId: selectedEntryId,
            onTapDay: (_, __) {},
            onCenteredDayChanged: (_) {},
          ),
        );

    await tester.pumpWidget(build(null));
    await tester.pumpAndSettle();
    // A plain Row inside SingleChildScrollView builds every day slot
    // eagerly (no lazy/sliver virtualization), so `find.text` still finds
    // "Place 19" in the element tree even though it's scrolled out of the
    // visible viewport — asserting on the scroll offset itself is what
    // actually distinguishes "off-screen" from "brought into view".
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, 0); // not scrolled initially

    await tester.pumpWidget(build('e19'));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0)); // scrolled into view
  });

  testWidgets(
      'selecting an entry via tap does not report a live-follow day change '
      'from the resulting programmatic scroll', (tester) async {
    final entries = [
      for (var i = 0; i < 20; i++)
        _e('e$i', DateTime(2026, 7, 1 + i), placeName: 'Place $i'),
    ];
    final reportedDays = <String>[];
    Widget build(String? selectedEntryId) => _wrap(
          JournalGalleryTimeline(
            entries: entries,
            selectedEntryId: selectedEntryId,
            onTapDay: (_, __) {},
            onCenteredDayChanged: (day) => reportedDays.add(day.first.id),
          ),
        );

    await tester.pumpWidget(build(null));
    await tester.pumpAndSettle();

    await tester.pumpWidget(build('e19'));
    // Pump through the 300ms ensureVisible animation in steps — this is
    // exactly the window where the old code's ScrollStartNotification
    // would misreport a live-follow day change mid-scroll.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(reportedDays, isEmpty);
  });

  testWidgets(
      'a second tap-driven selection while the first is still scrolling '
      'does not leave live-follow reporting stuck disabled', (tester) async {
    final entries = [
      for (var i = 0; i < 20; i++)
        _e('e$i', DateTime(2026, 7, 1 + i), placeName: 'Place $i'),
    ];
    final reportedDays = <String>[];
    Widget build(String? selectedEntryId) => _wrap(
          JournalGalleryTimeline(
            entries: entries,
            selectedEntryId: selectedEntryId,
            onTapDay: (_, __) {},
            onCenteredDayChanged: (day) => reportedDays.add(day.first.id),
          ),
        );

    await tester.pumpWidget(build(null));
    await tester.pumpAndSettle();

    await tester.pumpWidget(build('e10'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Second selection change lands mid-animation, superseding the first.
    // That resolves the FIRST ensureVisible's future early, so without a
    // generation guard the stale completion clears the latch while the
    // second scroll is still running.
    await tester.pumpWidget(build('e19'));
    await tester.pumpAndSettle();

    // Issue B proper: neither programmatic scroll may report. Without the
    // generation guard the superseded first future clears the latch
    // mid-flight and the second scroll's own notifications get reported.
    expect(reportedDays, isEmpty);

    // Issue A: both programmatic scrolls are done, so a real user drag
    // now must be reported — if _programmaticScroll got stuck true, this
    // list stays empty forever.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();

    expect(reportedDays, isNotEmpty);
  });

  testWidgets('scrolling reports the day closest to the viewport center',
      (tester) async {
    final entries = [
      for (var i = 0; i < 20; i++)
        _e('e$i', DateTime(2026, 7, 1 + i), placeName: 'Place $i'),
    ];
    List<JournalEntry>? lastCentered;
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: entries,
          selectedEntryId: null,
          onTapDay: (_, __) {},
          onCenteredDayChanged: (day) => lastCentered = day,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initial layout already reports whichever day starts closest to
    // center (ScrollStartNotification fires on the first drag below,
    // but a plain pump with no scroll yet won't have reported anything
    // — this asserts the FIRST report, once scrolling begins).
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();

    expect(lastCentered, isNotNull);
    // After scrolling left by 600px, the centered day should no longer
    // be the very first one (Place 0) — some later day is now closer to
    // the viewport's center.
    expect(lastCentered!.first.id, isNot('e0'));
  });

  testWidgets(
      'a grouped-day card renders the same height as a single-entry card',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: [
            _e('single', DateTime(2026, 7, 19), placeName: 'Krabi'),
            _e('a', DateTime(2026, 7, 20), placeName: 'Phuket'),
            _e('b', DateTime(2026, 7, 20, 12), placeName: 'Phuket'),
          ],
          selectedEntryId: null,
          onTapDay: (_, __) {},
          onCenteredDayChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cards = find.byType(PaperCard);
    expect(cards, findsNWidgets(2));
    final singleCardHeight = tester.getSize(cards.at(0)).height;
    final groupedCardHeight = tester.getSize(cards.at(1)).height;
    expect(groupedCardHeight, singleCardHeight);
  });

  testWidgets(
      'a squeezed strip shrinks the card width to match, leaving no dead '
      'space beside it', (tester) async {
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: [_e('a', DateTime(2026, 7, 20), placeName: 'Krabi')],
          selectedEntryId: null,
          onTapDay: (_, __) {},
          onCenteredDayChanged: (_) {},
        ),
        height: 100,
      ),
    );
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(PaperCard).first);
    // Full natural size is 150x130 (JournalGalleryCard.width/.photoHeight).
    // A squeezed 100px strip forces a shrink well below that — the old
    // FittedBox-based layout always reported the full 150 width to its
    // parent regardless of how much the content inside had shrunk,
    // leaving a dead-space wedge next to the visibly-smaller card. This
    // asserts the reported (and therefore painted-border) width actually
    // shrinks in proportion to the height, so nothing is left over.
    expect(size.height, lessThan(130));
    expect(size.width, lessThan(150));
    expect(size.width / size.height, closeTo(150 / 130, 0.01));
  });
}
