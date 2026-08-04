import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/presentation/journal_providers.dart';
import 'package:tripper/features/journal/presentation/trip_journal_tab.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/fake_journal_repository.dart';
import '../../helpers/fake_place_repository.dart';

final _trip = Trip(
  id: 'trip-1',
  name: 'Thailand',
  destinations: const ['Krabi'],
  colorTag: 0,
  archived: false,
  completionPromptShown: false,
);

Future<FakeJournalRepository> _pump(
  WidgetTester tester, {
  List<JournalEntry> entries = const [],
}) async {
  final repo = FakeJournalRepository(entries);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        journalRepositoryProvider.overrideWithValue(repo),
        placeRepositoryProvider.overrideWithValue(FakePlaceRepository([])),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body:
              TripJournalTab(trip: _trip, renderGlobe: false, renderMap: false),
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
  return repo;
}

void main() {
  testWidgets('empty state invites logging the first entry', (tester) async {
    await _pump(tester);
    expect(find.text('No journal entries yet'), findsOneWidget);
  });

  testWidgets('entries render in the timeline', (tester) async {
    await _pump(
      tester,
      entries: [
        JournalEntry(
          id: 'e1',
          tripId: 'trip-1',
          summary: 'Arrived in Krabi',
          loggedAt: DateTime(2026, 7, 20),
          createdAt: DateTime(2026, 7, 20),
        ),
      ],
    );
    expect(find.text('Arrived in Krabi'), findsOneWidget);
  });

  testWidgets('toggling to map view swaps the timeline for the map',
      (tester) async {
    await _pump(
      tester,
      entries: [
        JournalEntry(
          id: 'e1',
          tripId: 'trip-1',
          summary: 'Arrived in Krabi',
          loggedAt: DateTime(2026, 7, 20),
          createdAt: DateTime(2026, 7, 20),
        ),
      ],
    );
    expect(find.text('Arrived in Krabi'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Arrived in Krabi'), findsNothing);
    expect(find.byIcon(Icons.timeline), findsOneWidget);
  });

  testWidgets('"Add entry" opens the entry form sheet', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Add entry'));
    await tester.pumpAndSettle();
    // SectionLabel uppercases its text.
    expect(find.text('NEW ENTRY'), findsOneWidget);
  });
}
