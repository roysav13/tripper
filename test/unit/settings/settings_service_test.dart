import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripper/core/settings/settings_service.dart';

Future<ProviderContainer> containerWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme defaults to light, not system', () async {
    final container = await containerWith({});
    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  test('stored theme is restored', () async {
    final container = await containerWith({'theme_mode': 'dark'});
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('toggle flips and persists', () async {
    final container = await containerWith({});
    await container.read(themeModeProvider.notifier).toggle();
    expect(container.read(themeModeProvider), ThemeMode.dark);

    final prefs = container.read(sharedPreferencesProvider);
    expect(prefs.getString('theme_mode'), 'dark');

    await container.read(themeModeProvider.notifier).toggle();
    expect(prefs.getString('theme_mode'), 'light');
  });

  test('system mode persists too', () async {
    final container = await containerWith({});
    await container.read(themeModeProvider.notifier).set(ThemeMode.system);
    expect(
      container.read(sharedPreferencesProvider).getString('theme_mode'),
      'system',
    );
  });

  test('vault lock defaults on and persists when disabled', () async {
    final container = await containerWith({});
    expect(container.read(vaultLockEnabledProvider), isTrue);

    await container.read(vaultLockEnabledProvider.notifier).set(enabled: false);
    expect(container.read(vaultLockEnabledProvider), isFalse);
    expect(
      container.read(sharedPreferencesProvider).getBool('vault_lock_enabled'),
      isFalse,
    );
  });

  test('disabled lock is restored from storage', () async {
    final container = await containerWith({'vault_lock_enabled': false});
    expect(container.read(vaultLockEnabledProvider), isFalse);
  });

  test('locale defaults to English', () async {
    final container = await containerWith({});
    expect(container.read(localeProvider), const Locale('en'));
  });

  test('stored Hebrew locale is restored', () async {
    final container = await containerWith({'app_locale': 'he'});
    expect(container.read(localeProvider), const Locale('he'));
  });

  test('an unrecognized stored value falls back to English', () async {
    final container = await containerWith({'app_locale': 'fr'});
    expect(container.read(localeProvider), const Locale('en'));
  });

  test('set persists and updates state', () async {
    final container = await containerWith({});
    await container.read(localeProvider.notifier).set(const Locale('he'));
    expect(container.read(localeProvider), const Locale('he'));
    expect(
      container.read(sharedPreferencesProvider).getString('app_locale'),
      'he',
    );
  });

  test('nearby places is off by default', () async {
    final container = await containerWith({});
    expect(container.read(nearbyPlacesEnabledProvider), isFalse);
  });

  test('nearby places toggle persists', () async {
    final container = await containerWith({});
    await container
        .read(nearbyPlacesEnabledProvider.notifier)
        .set(enabled: true);
    expect(container.read(nearbyPlacesEnabledProvider), isTrue);
    expect(
      container
          .read(sharedPreferencesProvider)
          .getBool('nearby_places_enabled'),
      isTrue,
    );
  });

  test('stored nearby places toggle is restored', () async {
    final container = await containerWith({'nearby_places_enabled': true});
    expect(container.read(nearbyPlacesEnabledProvider), isTrue);
  });

  test('nearby API call count defaults to zero and persists increments',
      () async {
    final container = await containerWith({});
    expect(container.read(nearbyApiCallCountProvider), 0);

    await container.read(nearbyApiCallCountProvider.notifier).increment();
    await container.read(nearbyApiCallCountProvider.notifier).increment();

    expect(container.read(nearbyApiCallCountProvider), 2);
    expect(
      container.read(sharedPreferencesProvider).getInt('nearby_api_call_count'),
      2,
    );
  });

  test('stored nearby API call count is restored', () async {
    final container = await containerWith({'nearby_api_call_count': 7});
    expect(container.read(nearbyApiCallCountProvider), 7);
  });
}
