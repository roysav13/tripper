import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/presentation/journal_widgets.dart';
import 'package:tripper/l10n/app_localizations.dart';

JournalEntry _e(String id, DateTime loggedAt, {String summary = ''}) =>
    JournalEntry(
      id: id,
      tripId: 't1',
      summary: summary.isEmpty ? id : summary,
      loggedAt: loggedAt,
      createdAt: loggedAt,
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
  testWidgets('single-entry day renders its summary directly, tap edits it',
      (tester) async {
    JournalEntry? edited;
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: [_e('a', DateTime(2026, 7, 20), summary: 'Arrived')],
          onEdit: (e) => edited = e,
          onDelete: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Arrived'), findsOneWidget);
    await tester.tap(find.text('Arrived'));
    await tester.pump();
    expect(edited?.id, 'a');
  });

  testWidgets(
      'multi-entry day shows a count badge, tap opens the day list, '
      'tapping a row edits that entry', (tester) async {
    JournalEntry? edited;
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: [
            _e('morning', DateTime(2026, 7, 20, 9), summary: 'Woke up early'),
            _e('evening', DateTime(2026, 7, 20, 20), summary: 'Sunset walk'),
          ],
          onEdit: (e) => edited = e,
          onDelete: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    // The grouped card shows the first (earliest) entry's summary as its
    // own label — not each individual entry yet.
    expect(find.text('Woke up early'), findsOneWidget);
    expect(find.text('Sunset walk'), findsNothing);

    await tester.tap(find.text('Woke up early'));
    await tester.pumpAndSettle();

    // Day-list sheet now shows both — scoped to ListTile since the
    // grouped card behind the (non-dismissing) modal sheet still has
    // "Woke up early" mounted in the tree too.
    expect(find.widgetWithText(ListTile, 'Woke up early'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Sunset walk'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Sunset walk'));
    await tester.pumpAndSettle();
    expect(edited?.id, 'evening');
  });

  testWidgets('entries on different days each get their own dot and card',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: [
            _e('day1', DateTime(2026, 7, 19), summary: 'Day one'),
            _e('day2', DateTime(2026, 7, 20), summary: 'Day two'),
          ],
          onEdit: (_) {},
          onDelete: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Day one'), findsOneWidget);
    expect(find.text('Day two'), findsOneWidget);
    expect(find.text('2'), findsNothing); // no grouping badge — two days
  });

  testWidgets('empty-summary entry falls back to the "not written yet" label',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        JournalGalleryTimeline(
          entries: [
            JournalEntry(
              id: 'stub',
              tripId: 't1',
              summary: '',
              loggedAt: DateTime(2026, 7, 20),
              createdAt: DateTime(2026, 7, 20),
            ),
          ],
          onEdit: (_) {},
          onDelete: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not written yet'), findsOneWidget);
  });
}
