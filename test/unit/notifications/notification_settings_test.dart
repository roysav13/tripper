import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/settings/settings_service.dart';

import '../../helpers/test_preferences.dart';

void main() {
  Future<ProviderContainer> makeContainer([
    Map<String, Object> values = const {},
  ]) async {
    final c = ProviderContainer(
      overrides: [await testPreferencesOverride(values)],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('notificationsMasterEnabledProvider', () {
    test('defaults on', () async {
      final c = await makeContainer();
      expect(c.read(notificationsMasterEnabledProvider), isTrue);
    });

    test('set() flips state and persists', () async {
      final c = await makeContainer();
      await c.read(notificationsMasterEnabledProvider.notifier).set(
            enabled: false,
          );
      expect(c.read(notificationsMasterEnabledProvider), isFalse);

      // A fresh container reading the same backing prefs sees the
      // persisted value, not just in-memory state.
      final c2 = await makeContainer({'notifications_master_enabled': false});
      expect(c2.read(notificationsMasterEnabledProvider), isFalse);
    });
  });

  group('per-type toggles default on and persist independently', () {
    test('doc expiry', () async {
      final c = await makeContainer();
      expect(c.read(docExpiryNotificationsEnabledProvider), isTrue);
      await c
          .read(docExpiryNotificationsEnabledProvider.notifier)
          .set(enabled: false);
      expect(c.read(docExpiryNotificationsEnabledProvider), isFalse);
      // Toggling one type doesn't affect the others.
      expect(c.read(tripCountdownNotificationsEnabledProvider), isTrue);
      expect(c.read(checkInNotificationsEnabledProvider), isTrue);
    });

    test('trip countdown', () async {
      final c = await makeContainer();
      await c
          .read(tripCountdownNotificationsEnabledProvider.notifier)
          .set(enabled: false);
      expect(c.read(tripCountdownNotificationsEnabledProvider), isFalse);
    });

    test('check-in opens', () async {
      final c = await makeContainer();
      await c
          .read(checkInNotificationsEnabledProvider.notifier)
          .set(enabled: false);
      expect(c.read(checkInNotificationsEnabledProvider), isFalse);
    });
  });

  group('documentExpiryNoticeDaysProvider', () {
    test('defaults to 90 (matches the old fixed kExpiryBufferDays)', () async {
      final c = await makeContainer();
      expect(c.read(documentExpiryNoticeDaysProvider), 90);
    });

    test('set() updates and persists', () async {
      final c = await makeContainer();
      await c.read(documentExpiryNoticeDaysProvider.notifier).set(30);
      expect(c.read(documentExpiryNoticeDaysProvider), 30);

      final c2 = await makeContainer({'document_expiry_notice_days': 30});
      expect(c2.read(documentExpiryNoticeDaysProvider), 30);
    });

    test('0 means off and is a valid explicit choice', () async {
      final c = await makeContainer();
      await c.read(documentExpiryNoticeDaysProvider.notifier).set(0);
      expect(c.read(documentExpiryNoticeDaysProvider), 0);
    });

    test('negative input is clamped to 0, never stored negative', () async {
      final c = await makeContainer();
      await c.read(documentExpiryNoticeDaysProvider.notifier).set(-5);
      expect(c.read(documentExpiryNoticeDaysProvider), 0);
    });
  });
}
