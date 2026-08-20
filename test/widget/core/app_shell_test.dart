import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:tripper/core/sharing/maps_link.dart';
import 'package:tripper/core/sharing/maps_list_scraper.dart';
import 'package:tripper/core/sharing/share_intent_service.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/core/widgets/app_shell.dart';
import 'package:tripper/features/places/presentation/maps_list_import_screen.dart';
import 'package:tripper/l10n/app_localizations.dart';

class _FakeMapsListScraper implements MapsListScraper {
  @override
  Future<ScrapedMapsList?> scrape(String listUrl) async =>
      const ScrapedMapsList(title: 'Japan', placeNames: ['Sensō-ji']);
}

GoRouter _router() => GoRouter(
      initialLocation: '/trips',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/trips',
                  builder: (context, state) =>
                      const Scaffold(body: Text('trips-tab')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/vault',
                  builder: (context, state) =>
                      const Scaffold(body: Text('vault-tab')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/places',
                  builder: (context, state) =>
                      const Scaffold(body: Text('places-tab')),
                ),
              ],
            ),
          ],
        ),
      ],
    );

Widget _app(Stream<IncomingShare> shares) => ProviderScope(
      overrides: [
        incomingSharesProvider.overrideWith((ref) => shares),
        // A client that throws on any request proves these tests' shares
        // (full, non-short URLs) never touch the network — see Task 1.
        mapsLinkServiceProvider.overrideWithValue(
          MapsLinkService(
            MockClient(
              (request) async =>
                  throw Exception('unexpected request to ${request.url}'),
            ),
          ),
        ),
        mapsListScraperProvider.overrideWithValue(_FakeMapsListScraper()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router(),
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
  // A single-place share's routing (openMapsShareResult -> AddPlaceScreen)
  // is exercised by maps_share_routing's own call sites in
  // places_screen_test.dart. It's not repeated here: app_shell.dart's
  // production AddPlaceScreen.open() call doesn't set renderMap: false,
  // so a real GoogleMap platform view would try to mount in this test —
  // exactly what AddPlaceScreen's own widget test avoids by using
  // renderMap: false (see add_place_screen.dart's doc comment). This test
  // file sticks to the genuinely new behavior instead.
  testWidgets('a list share opens MapsListImportScreen on the Places tab',
      (tester) async {
    await tester.pumpWidget(
      _app(
        Stream.value(
          const IncomingShare(
            texts: [
              'https://www.google.com/maps/@/data=!3m1!4b1!4m3!11m2!2sX!3e3',
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // MapsListImportScreen is pushed as an opaque fullscreenDialog route on
    // the root navigator, so the Places tab underneath is still mounted but
    // no longer "onstage" per Flutter's Overlay stacking (Offstage's own
    // literal flag stays false — this is about route-covering, not the
    // Offstage widget) — skipOffstage: false confirms goBranch(2) actually
    // ran instead of merely trusting a covered widget's presence.
    expect(
      find.text('places-tab', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(MapsListImportScreen), findsOneWidget);
  });

  // The pre-existing file-share branch (showDocumentFormSheet on the Vault
  // tab) is intentionally not re-tested here either: it's untouched by
  // this change, and exercising it would need the document/vault provider
  // graph mocked (documentRepositoryProvider and friends) purely to
  // satisfy a screen this feature never touches — the same
  // disproportionate-for-unrelated-code call as the AddPlaceScreen/
  // GoogleMap exclusion above.
  testWidgets('non-maps text is ignored — stays on the trips tab',
      (tester) async {
    await tester.pumpWidget(
      _app(Stream.value(const IncomingShare(texts: ['just some text']))),
    );
    await tester.pumpAndSettle();

    expect(find.text('trips-tab'), findsOneWidget);
  });
}
