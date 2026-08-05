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
}
