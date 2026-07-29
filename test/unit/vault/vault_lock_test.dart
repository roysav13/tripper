import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/database/database_provider.dart';
import 'package:tripper/core/security/vault_lock.dart';

import '../../helpers/test_preferences.dart';

void main() {
  late DateTime now;
  late int authCalls;
  late bool authResult;
  late ProviderContainer container;

  // The lock reads the "vault lock enabled" setting, so preferences must
  // be available even in this pure-logic test.
  Future<ProviderContainer> makeContainer({bool lockEnabled = true}) async {
    final c = ProviderContainer(
      overrides: [
        await testPreferencesOverride({'vault_lock_enabled': lockEnabled}),
        clockProvider.overrideWithValue(() => now),
        biometricAuthenticatorProvider.overrideWithValue((reason) async {
          authCalls++;
          return authResult;
        }),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    now = DateTime(2026, 7, 19, 10, 0);
    authCalls = 0;
    authResult = true;
    container = await makeContainer();
  });

  Future<bool> unlock() =>
      container.read(vaultLockProvider.notifier).ensureUnlocked('test');

  test('starts locked; successful auth unlocks', () async {
    expect(container.read(vaultLockProvider), isFalse);
    expect(await unlock(), isTrue);
    expect(container.read(vaultLockProvider), isTrue);
    expect(authCalls, 1);
  });

  test('within the session no re-auth is needed', () async {
    await unlock();
    now = now.add(const Duration(minutes: 1, seconds: 59));
    expect(await unlock(), isTrue);
    expect(authCalls, 1);
  });

  test('after the session expires auth is required again', () async {
    await unlock();
    now = now.add(kVaultUnlockSession);
    expect(await unlock(), isTrue);
    expect(authCalls, 2);
  });

  test('failed auth keeps the vault locked', () async {
    authResult = false;
    expect(await unlock(), isFalse);
    expect(container.read(vaultLockProvider), isFalse);
    // A later attempt prompts again.
    authResult = true;
    expect(await unlock(), isTrue);
    expect(authCalls, 2);
  });

  test('explicit lock ends the session immediately', () async {
    await unlock();
    container.read(vaultLockProvider.notifier).lock();
    expect(container.read(vaultLockProvider), isFalse);
    await unlock();
    expect(authCalls, 2);
  });

  test('lock disabled in settings opens without prompting', () async {
    container = await makeContainer(lockEnabled: false);
    expect(await unlock(), isTrue);
    expect(authCalls, 0);
  });
}
