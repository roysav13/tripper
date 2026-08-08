import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/presentation/journal_entry_form_sheet.dart';
import 'package:tripper/features/journal/presentation/journal_providers.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_journal_repository.dart';

final _today = DateTime(2026, 7, 23, 9, 30);

Future<FakeJournalRepository> _pump(WidgetTester tester) async {
  final repo = FakeJournalRepository([]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        journalRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => _today),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showJournalEntryFormSheet(
                context,
                tripId: 'trip-1',
              ),
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
  return repo;
}

void main() {
  testWidgets('saving without a summary creates the entry with an empty '
      'summary', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final entries = await repo.watchForTrip('trip-1').first;
    expect(entries, hasLength(1));
    expect(entries.single.summary, isEmpty);
  });

  testWidgets('the logged-at header defaults to clock(), shown as date + time',
      (tester) async {
    await _pump(tester);
    expect(
      find.text(DateFormat('EEEE, d MMMM').format(_today)),
      findsOneWidget,
    );
    // MonoText uppercases, but digits and "·" are unaffected.
    expect(find.text('2026 · 09:30'), findsOneWidget);
  });

  testWidgets('saving with a summary creates the entry via the repository',
      (tester) async {
    final repo = await _pump(tester);
    await tester.enterText(find.byType(TextField).first, 'Arrived in Krabi');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final entries = await repo.watchForTrip('trip-1').first;
    expect(entries, hasLength(1));
    expect(entries.single.summary, 'Arrived in Krabi');
    expect(entries.single.tripId, 'trip-1');
    expect(entries.single.loggedAt, _today);
  });
}
