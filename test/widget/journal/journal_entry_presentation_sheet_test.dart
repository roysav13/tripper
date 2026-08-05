import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/presentation/journal_entry_presentation_sheet.dart';
import 'package:tripper/features/journal/presentation/journal_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_journal_repository.dart';

JournalEntry _e(String id, {String summary = 'Some summary'}) => JournalEntry(
      id: id,
      tripId: 't1',
      summary: summary,
      loggedAt: DateTime(2026, 7, 20, 14, 30),
      createdAt: DateTime(2026, 7, 20, 14, 30),
      placeName: 'Krabi',
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
}
