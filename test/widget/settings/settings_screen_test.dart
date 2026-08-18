import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/security/vault_lock.dart';
import 'package:tripper/core/settings/settings_service.dart';
import 'package:tripper/core/theme/app_theme.dart';
import 'package:tripper/features/places/data/google_places_geocoder.dart';
import 'package:tripper/features/settings/presentation/settings_screen.dart';
import 'package:tripper/l10n/app_localizations.dart';

import '../../helpers/test_preferences.dart';

Future<Widget> _app() async => ProviderScope(
      overrides: [
        await testPreferencesOverride(),
        biometricAuthenticatorProvider.overrideWithValue((_) async => true),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const SettingsScreen(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('he')],
      ),
    );

void main() {
  testWidgets('selecting Hebrew persists and updates localeProvider',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('עברית'));
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(SettingsScreen));
    final container2 = ProviderScope.containerOf(element);
    expect(container2.read(localeProvider), const Locale('he'));
    expect(
      container2.read(sharedPreferencesProvider).getString('app_locale'),
      'he',
    );
  });

  testWidgets('English is selected by default', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(SettingsScreen));
    final container = ProviderScope.containerOf(element);
    expect(container.read(localeProvider), const Locale('en'));
  });

  testWidgets('nearby places toggle defaults off and switches on',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          await testPreferencesOverride(),
          biometricAuthenticatorProvider.overrideWithValue((_) async => true),
          mapsApiKeyConfiguredProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('he')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.widgetWithText(
      SwitchListTile,
      'Nearby places',
      skipOffstage: false,
    );
    expect(toggle, findsOneWidget);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);

    // The switch sits just past the default 600px test viewport;
    // ensureVisible/scrollUntilVisible both no-op once a widget is merely
    // present in the ListView's cache extent, so drag the list directly.
    await tester.drag(find.byType(ListView), const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(SettingsScreen));
    final container = ProviderScope.containerOf(element);
    expect(container.read(nearbyPlacesEnabledProvider), isTrue);
  });

  testWidgets('nearby places call count subtitle reflects stored count',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          await testPreferencesOverride({'nearby_api_call_count': 3}),
          biometricAuthenticatorProvider.overrideWithValue((_) async => true),
          mapsApiKeyConfiguredProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('he')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 lookups this install'), findsOneWidget);
  });
}
