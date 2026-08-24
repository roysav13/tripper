import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/settings/settings_service.dart';

Future<ProviderContainer> containerWith(
  Map<String, Object> values, {
  DateTime? now,
}) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (now != null) clockProvider.overrideWithValue(() => now),
    ],
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

  group('placesApiCallCountProvider (monthly quota counter)', () {
    test('defaults to zero and persists increments', () async {
      final container = await containerWith(
        {},
        now: DateTime(2026, 8, 22),
      );
      expect(container.read(placesApiCallCountProvider), 0);

      await container.read(placesApiCallCountProvider.notifier).increment();
      await container.read(placesApiCallCountProvider.notifier).increment();

      expect(container.read(placesApiCallCountProvider), 2);
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getInt('places_api_call_count'), 2);
      expect(prefs.getString('places_api_call_period'), '2026-08');
    });

    test('a count from the current month is restored', () async {
      final container = await containerWith(
        {
          'places_api_call_count': 42,
          'places_api_call_period': '2026-08',
        },
        now: DateTime(2026, 8, 22),
      );
      expect(container.read(placesApiCallCountProvider), 42);
    });

    test('a count from a previous month reads as zero', () async {
      final container = await containerWith(
        {
          'places_api_call_count': 4999,
          'places_api_call_period': '2026-07',
        },
        now: DateTime(2026, 8, 1),
      );
      expect(container.read(placesApiCallCountProvider), 0);
    });

    test('incrementing after a month rollover restarts from 1', () async {
      final container = await containerWith(
        {
          'places_api_call_count': 4999,
          'places_api_call_period': '2026-07',
        },
        now: DateTime(2026, 8, 1),
      );

      await container.read(placesApiCallCountProvider.notifier).increment();

      expect(container.read(placesApiCallCountProvider), 1);
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getInt('places_api_call_count'), 1);
      expect(prefs.getString('places_api_call_period'), '2026-08');
    });
  });
}
