import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/security/vault_lock.dart';
import 'package:tripper/core/settings/settings_service.dart';
import 'package:tripper/core/theme/app_theme.dart';
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
}
