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

  testWidgets(
      'entries render in the timeline, tapping one opens the presentation '
      'view', (tester) async {
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
    // The card shows the date, not the summary.
    expect(find.text('20 JUL'), findsOneWidget);
    expect(find.text('Arrived in Krabi'), findsNothing);

    await tester.tap(find.text('20 JUL'));
    await tester.pumpAndSettle();

    // The presentation view now shows the summary.
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
    expect(find.text('20 JUL'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pumpAndSettle();

    expect(find.text('20 JUL'), findsNothing);
    expect(find.byIcon(Icons.timeline), findsOneWidget);
  });

  testWidgets(
      'tapping a globe dot selects the matching gallery card '
      '(accent border)', (tester) async {
    await _pump(
      tester,
      entries: [
        JournalEntry(
          id: 'e1',
          tripId: 'trip-1',
          summary: 'Arrived',
          loggedAt: DateTime(2026, 7, 19),
          createdAt: DateTime(2026, 7, 19),
          lat: 8.0,
          lng: 98.8,
        ),
        JournalEntry(
          id: 'e2',
          tripId: 'trip-1',
          summary: 'Next day',
          loggedAt: DateTime(2026, 7, 20),
          createdAt: DateTime(2026, 7, 20),
          lat: 7.9,
          lng: 98.7,
        ),
      ],
    );
    // renderGlobe: false in _pump renders each located entry as a plain
    // tappable Icon (Icons.circle for entries with no photo) — tapping
    // the first one fires JournalGlobe.onEntryTap with entry 'e1', which
    // TripJournalTab wires to select it.
    await tester.tap(find.byIcon(Icons.circle).first);
    await tester.pumpAndSettle();

    // PaperCard only sets Material.shape.side to a 1.0-width border when
    // borderColor is non-null (the "selected" state) — the default
    // hairline path uses AppShape.hairlineWidth (0.5) instead. At least
    // one gallery card should now have the 1.0-width accent border.
    final selectedCards = tester
        .widgetList<Material>(find.byType(Material))
        .where((m) => m.shape is RoundedRectangleBorder)
        .where((m) => (m.shape as RoundedRectangleBorder).side.width == 1.0)
        .toList();
    expect(selectedCards, isNotEmpty);
  });

  testWidgets(
      'swiping the presentation sheet to a new entry updates the gallery '
      'selection after the sheet closes', (tester) async {
    await _pump(
      tester,
      entries: [
        JournalEntry(
          id: 'e1',
          tripId: 'trip-1',
          summary: 'Morning market',
          loggedAt: DateTime(2026, 7, 20, 9),
          createdAt: DateTime(2026, 7, 20, 9),
        ),
        JournalEntry(
          id: 'e2',
          tripId: 'trip-1',
          summary: 'Evening at the pier',
          loggedAt: DateTime(2026, 7, 20, 19),
          createdAt: DateTime(2026, 7, 20, 19),
        ),
      ],
    );

    // Two same-day entries render as one grouped card with a count badge —
    // tapping it opens the presentation sheet at index 0 (the earliest
    // entry).
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.text('Morning market'), findsOneWidget);

    // Swipe the sheet's PageView to the second entry — TripJournalTab's
    // onPageChanged wiring should follow this into _selectedEntryId.
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Evening at the pier'), findsOneWidget);
    expect(find.text('Morning market'), findsNothing);

    // Dismiss the sheet by tapping the barrier above it (isDismissible
    // defaults to true for showModalBottomSheet).
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Evening at the pier'), findsNothing); // sheet closed

    // The gallery's grouped card for this day should still carry the
    // accent-bordered "selected" state, proving the swipe -> tab state ->
    // gallery seam survived the round trip back from the sheet. Same
    // technique as the globe-tap coordination test above: PaperCard only
    // sets a 1.0-width Material border when borderColor is non-null (the
    // selected state) — the default hairline path uses 0.5 instead.
    final selectedCards = tester
        .widgetList<Material>(find.byType(Material))
        .where((m) => m.shape is RoundedRectangleBorder)
        .where((m) => (m.shape as RoundedRectangleBorder).side.width == 1.0)
        .toList();
    expect(selectedCards, isNotEmpty);
  });

  testWidgets('"Add entry" opens the entry form sheet', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Add entry'));
    await tester.pumpAndSettle();
    // SectionLabel uppercases its text.
    expect(find.text('NEW ENTRY'), findsOneWidget);
  });
}
