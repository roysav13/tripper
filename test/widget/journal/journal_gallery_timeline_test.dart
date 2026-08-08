import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/presentation/journal_widgets.dart';
import 'package:tripper/l10n/app_localizations.dart';

JournalEntry _e(String id, DateTime loggedAt, {String? placeName}) =>
    JournalEntry(
      id: id,
      tripId: 't1',
      summary: 'summary for $id',
      loggedAt: loggedAt,
      createdAt: loggedAt,
      placeName: placeName,
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: SizedBox(height: 200, child: child)),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );

void main() {
  testWidgets(
      'single-entry day: tapping it reports that day with index 0',
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
}
