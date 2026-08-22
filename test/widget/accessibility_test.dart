import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/app.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/location/location_providers.dart';
import 'package:tripper/core/location/location_service.dart';
import 'package:tripper/core/security/vault_lock.dart';
import 'package:tripper/core/settings/settings_service.dart';
import 'package:tripper/features/expenses/presentation/expense_providers.dart';
import 'package:tripper/features/places/domain/place.dart';
import 'package:tripper/features/places/presentation/place_collection_providers.dart';
import 'package:tripper/features/places/presentation/place_providers.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/trips/presentation/trip_card.dart';
import 'package:tripper/features/trips/presentation/trip_providers.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/features/vault/presentation/document_providers.dart';

import '../helpers/fake_document_repository.dart';
import '../helpers/fake_expense_repository.dart';
import '../helpers/fake_location_service.dart';
import '../helpers/fake_place_collection_repository.dart';
import '../helpers/fake_place_repository.dart';
import '../helpers/fake_trip_repository.dart';
import '../helpers/test_preferences.dart';

/// Fixes the app's theme mode for a test regardless of stored preferences —
/// `ThemeModeController` is a `Notifier`, so this is the direct override
/// point (`themeModeProvider.overrideWith`), not a side channel via prefs.
class _FixedThemeModeController extends ThemeModeController {
  _FixedThemeModeController(this._mode);
  final ThemeMode _mode;
  @override
  ThemeMode build() => _mode;
}

/// Permanent guardrails (M4 §4.3): tap targets, labels, contrast.
Future<Widget> _populatedApp({
  String locale = 'en',
  ThemeMode themeMode = ThemeMode.light,
}) async =>
    ProviderScope(
      overrides: [
        await testPreferencesOverride({'app_locale': locale}),
        testSharesOverride(),
        themeModeProvider.overrideWith(
          () => _FixedThemeModeController(themeMode),
        ),
        tripRepositoryProvider.overrideWithValue(
          FakeTripRepository([
            Trip(
              id: 't1',
              name: 'Thailand',
              destinations: const ['Krabi'],
              startDate: DateTime(2026, 7, 16),
              endDate: DateTime(2026, 7, 27),
              completionPromptShown: true,
            ),
          ]),
        ),
        documentRepositoryProvider.overrideWithValue(
          FakeDocumentRepository([
            Document(
              id: 'd1',
              title: 'Passport',
              category: DocumentCategory.passportId,
              createdAt: DateTime(2026, 7, 19),
              isPinned: true,
              tripIds: const ['t1'],
            ),
          ]),
        ),
        placeRepositoryProvider.overrideWithValue(
          FakePlaceRepository([
            const Place(
              id: 'p1',
              name: 'Railay viewpoint',
              country: 'Thailand',
              city: 'Krabi',
              tripId: 't1',
              category: PlaceCategory.attraction,
            ),
          ]),
        ),
        // Without this the M5.5b conversion wiring reaches the real Drift
        // database (via expensesDao), opening a second AppDatabase.
        expenseRepositoryProvider.overrideWithValue(FakeExpenseRepository()),
        // PlacesScreen now watches the Locations lists providers.
        placeCollectionRepositoryProvider.overrideWithValue(
          FakePlaceCollectionRepository([]),
        ),
        // Without this the real GeolocatorLocationService reaches the OS
        // (win32 Location API on desktop) when the places filter sheet's
        // Distance option is rendered.
        locationServiceProvider.overrideWithValue(
          FakeLocationService(
            const LocationUnavailable(LocationUnavailableReason.error),
          ),
        ),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 19)),
        launchRedirectDoneProvider.overrideWith((ref) => true),
        biometricAuthenticatorProvider.overrideWithValue((_) async => true),
      ],
      child: const TripperApp(),
    );

void main() {
  testWidgets('trips list meets tap target, label and contrast guidelines',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(await _populatedApp());
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('vault meets tap target and contrast guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(await _populatedApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vault'));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('places meets tap target and contrast guidelines',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(await _populatedApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Places'));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  // Dark mode is never exercised above — `_populatedApp` defaults to light,
  // and the app itself currently defaults to light too (see
  // settings_service.dart) — so all three above only ever render the light
  // theme. These mirror them under ThemeMode.dark; this is what actually
  // catches a WCAG-failing dark-mode token.
  testWidgets(
      'trips list meets tap target, label and contrast guidelines (dark)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(await _populatedApp(themeMode: ThemeMode.dark));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('vault meets tap target and contrast guidelines (dark)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(await _populatedApp(themeMode: ThemeMode.dark));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vault'));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('places meets tap target and contrast guidelines (dark)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(await _populatedApp(themeMode: ThemeMode.dark));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Places'));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets(
      'trip detail (hero, glass topbar/tabbar, Documents/Places/Expenses '
      'tabs, and the places filter sheet) meets contrast guidelines',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(await _populatedApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TripCard));
    await tester.pumpAndSettle();

    final tabs = find.byType(Tab);
    await tester.tap(tabs.at(0)); // Documents
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await tester.tap(tabs.at(1)); // Places
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(tabs.at(2)); // Expenses
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    handle.dispose();
  });

  testWidgets(
      'trip detail meets contrast guidelines (dark) — same tour as the '
      'light-mode test above', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(await _populatedApp(themeMode: ThemeMode.dark));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TripCard));
    await tester.pumpAndSettle();

    final tabs = find.byType(Tab);
    await tester.tap(tabs.at(0)); // Documents
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await tester.tap(tabs.at(1)); // Places
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(tabs.at(2)); // Expenses
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    handle.dispose();
  });

  testWidgets('layout survives 1.3x text scaling without overflow',
      (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: await _populatedApp(),
      ),
    );
    await tester.pumpAndSettle();
    // Any RenderFlex overflow throws in tests, so reaching here is the pass.
    expect(find.text('Thailand'), findsOneWidget);
  });

  testWidgets(
      'app renders RTL and without overflow in Hebrew across the main tabs',
      (tester) async {
    await tester.pumpWidget(await _populatedApp(locale: 'he'));
    await tester.pumpAndSettle();

    // Navigate by icon, not translated label text — the label text is
    // now Hebrew, and this test shouldn't need to know this plan's own
    // word choices to drive navigation.
    final navBar = find.byType(NavigationBar);
    // MaterialApp's own element has no Directionality ancestor — it's the
    // widget that introduces one for everything below it — so read the
    // resolved direction from a descendant instead.
    expect(
      Directionality.of(tester.element(navBar)),
      TextDirection.rtl,
    );

    // The trip name "Thailand" is English fixture data inside a Hebrew
    // (RTL) app — it must render LTR so a one-line ellipsis truncates from
    // its trailing edge instead of clipping the start of the word.
    expect(
      tester.widget<Text>(find.text('Thailand')).textDirection,
      TextDirection.ltr,
    );

    // Trip Detail excursion (Documents/Places/Expenses tabs + the Places
    // filter sheet) — a stack push from a TripCard tap, not a bottom-nav
    // branch, so the pre-Phase-5 sweep above never reached it. Journal is
    // deliberately excluded here — see this plan's Global Constraints;
    // it gets its own RTL coverage in trip_journal_tab_test.dart instead.
    await tester.tap(find.byType(TripCard));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Trip is "active" (today falls within start/end), so Trip Detail
    // opens on the Expenses tab (index 2) by default — visit all in a
    // fixed, known order regardless.
    final tabs = find.byType(Tab);
    expect(tabs, findsNWidgets(5));

    await tester.tap(tabs.at(0)); // Documents
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(tabs.at(1)); // Places
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Open the Places filter sheet (GlassChrome over the trip's places
    // list) — never exercised under RTL before this.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Dismiss via the modal barrier, away from the sheet's own content.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Same for the (solid, non-glass) sort sheet.
    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(tabs.at(2)); // Expenses
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Back to the Trips list before continuing the existing sweep below.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: navBar,
        matching: find.byIcon(Icons.folder_outlined),
      ),
    );
    await tester.pumpAndSettle();
    // Same check for the vault tab's document title — pinned, so it
    // renders in both the quick-access row and the main list.
    expect(
      tester
          .widgetList<Text>(find.text('Passport'))
          .map((t) => t.textDirection),
      everyElement(TextDirection.ltr),
    );

    await tester.tap(
      find.descendant(
        of: navBar,
        matching: find.byIcon(Icons.place_outlined),
      ),
    );
    await tester.pumpAndSettle();
    // Same check for the places tab's place name.
    expect(
      tester.widget<Text>(find.text('Railay viewpoint')).textDirection,
      TextDirection.ltr,
    );

    await tester.tap(
      find.descendant(
        of: navBar,
        matching: find.byIcon(Icons.luggage_outlined),
      ),
    );
    await tester.pumpAndSettle();

    // No RenderFlex overflow surfacing across any of these screens is the
    // actual check — same "reaching this line is the pass" pattern the
    // existing 1.3x text-scale test above already uses.
    expect(tester.takeException(), isNull);
  });
}
