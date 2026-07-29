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
}
