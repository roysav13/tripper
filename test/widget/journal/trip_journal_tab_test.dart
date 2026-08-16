import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/theme/app_colors.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/glass_chrome.dart';
import 'package:tripper/core/widgets/mono_text.dart';
import 'package:tripper/features/journal/domain/journal_entry.dart';
import 'package:tripper/features/journal/presentation/journal_globe.dart';
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
  ThemeData? theme,
}) async {
  final repo = FakeJournalRepository(entries);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        journalRepositoryProvider.overrideWithValue(repo),
        placeRepositoryProvider.overrideWithValue(FakePlaceRepository([])),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light(),
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

  testWidgets(
      'the stats line renders as a floating overlay, not a separate '
      'header — add and toggle actions still reachable', (tester) async {
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

    // journalStatsLine: "{entries} entries · {places} places visited",
    // MonoText uppercases it. 1 entry, 0 visited places (FakePlaceRepository
    // is empty in _pump's setup).
    expect(find.text('1 ENTRIES · 0 PLACES VISITED'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
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
      'scrolling the gallery does not throw (live-follow wiring smoke test)',
      (tester) async {
    final entries = [
      for (var i = 0; i < 20; i++)
        JournalEntry(
          id: 'e$i',
          tripId: 'trip-1',
          summary: 'Entry $i',
          loggedAt: DateTime(2026, 7, 1 + i),
          createdAt: DateTime(2026, 7, 1 + i),
          lat: 8.0 + i * 0.01,
          lng: 98.8 + i * 0.01,
          placeName: 'Place $i',
        ),
    ];
    await _pump(tester, entries: entries);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // renderGlobe: false strips the *rendered* globe, but the JournalGlobe
    // widget object still carries the prop — so the live-follow id itself
    // is assertable, not just "nothing threw". Can't predict the exact id
    // without duplicating the viewport-center geometry, but it must have
    // moved off the first entry.
    final globe = tester.widget<JournalGlobe>(find.byType(JournalGlobe));
    expect(globe.liveFollowEntryId, isNotNull);
    expect(globe.liveFollowEntryId, isNot('e0'));
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

  testWidgets(
      'the floating top chrome stays a fixed dark glass panel in dark app '
      'theme, not an inverted bright one (regression: it used to hand-roll '
      'panels from theme-flipping colors.inkPrimary/colors.surface)',
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
      theme: AppTheme.dark(),
    );

    // Both the stats pill and the two icon buttons are GlassChrome now,
    // each pinned to the fixed dark tint regardless of app theme.
    final glassChromes =
        tester.widgetList<GlassChrome>(find.byType(GlassChrome));
    expect(glassChromes.length, greaterThanOrEqualTo(3));
    for (final chrome in glassChromes) {
      expect(chrome.tint, AppColors.dark.surface);
    }

    // The stats line's ink is fixed dark-mode ink, not colors.surface
    // (which would be dark-theme's near-white-on-dark-card tone — wrong
    // against the glass panel's own fixed dark tint).
    final statsMono = tester
        .widgetList<MonoText>(find.byType(MonoText))
        .where((m) => m.text.toUpperCase().contains('ENTRIES'))
        .single;
    expect(statsMono.color, AppColors.dark.inkPrimary);

    // Same for both icon buttons' glyphs.
    expect(
      tester.widget<Icon>(find.byIcon(Icons.add)).color,
      AppColors.dark.inkPrimary,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.map_outlined)).color,
      AppColors.dark.inkPrimary,
    );

    // Regression-proofing for the icon buttons' glass panel shape:
    // GlassChrome sizes itself to its child's actual layout box, and
    // Material 3's IconButton occupies a padded 48x48 tap-target box by
    // default (even though its own visible CircleBorder stays 36px) — so
    // a naive `borderRadius: circular(36 / 2)` paints an 48x48
    // rounded-square "squircle" with radius 18, not a true circle. Assert
    // the rendered box is square AND its border radius is exactly half
    // its side length (a true circle), not a mismatched smaller radius on
    // a bigger box.
    final addButtonChrome = tester.widget<GlassChrome>(
      find.ancestor(
        of: find.byIcon(Icons.add),
        matching: find.byType(GlassChrome),
      ),
    );
    final addButtonSize = tester.getSize(
      find.ancestor(
        of: find.byIcon(Icons.add),
        matching: find.byType(GlassChrome),
      ),
    );
    expect(addButtonSize.width, addButtonSize.height);
    expect(
      addButtonChrome.borderRadius.topLeft.x,
      addButtonSize.width / 2,
    );
  });

  testWidgets(
      'the floating top chrome uses the same fixed dark tokens under '
      'light app theme too, not colors.light\'s bright surface/ink '
      '(proves the tokens are genuinely fixed, not coincidentally '
      'matching one theme)', (tester) async {
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
      theme: AppTheme.light(),
    );

    final glassChromes =
        tester.widgetList<GlassChrome>(find.byType(GlassChrome));
    expect(glassChromes.length, greaterThanOrEqualTo(3));
    for (final chrome in glassChromes) {
      expect(chrome.tint, AppColors.dark.surface);
    }

    final statsMono = tester
        .widgetList<MonoText>(find.byType(MonoText))
        .where((m) => m.text.toUpperCase().contains('ENTRIES'))
        .single;
    expect(statsMono.color, AppColors.dark.inkPrimary);
  });

  testWidgets('a stream failure shows the error state with retry',
      (tester) async {
    final repo = FakeJournalRepository([
      JournalEntry(
        id: 'e1',
        tripId: 'trip-1',
        summary: 'Arrived in Krabi',
        loggedAt: DateTime(2026, 7, 20),
        createdAt: DateTime(2026, 7, 20),
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalRepositoryProvider.overrideWithValue(repo),
          placeRepositoryProvider.overrideWithValue(FakePlaceRepository([])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TripJournalTab(
              trip: _trip,
              renderGlobe: false,
              renderMap: false,
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

    repo.emitError(Exception('boom'));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });
}
