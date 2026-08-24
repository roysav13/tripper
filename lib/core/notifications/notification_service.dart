import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';

export 'notification_bootstrap_io.dart'
    if (dart.library.js_interop) 'notification_bootstrap_web.dart'
    show createNotificationScheduler, kSupportsScheduledNotifications;

/// The three reminder types SPEC §3.2.1 groups under "one scheduling
/// subsystem" (document-expiry warnings, trip-countdown nudges,
/// check-in-opens). M5.1 only builds the subsystem itself — M5.2/M5.3
/// wire real sources in.
enum NotificationTriggerType { documentExpiry, tripCountdown, checkInOpens }

/// A single scheduled reminder, identified by the entity it's about and
/// which trigger fired it. [id] is derived deterministically from those
/// three fields, so re-scheduling the same reminder (e.g. re-saving a
/// document) replaces the old alarm instead of stacking a duplicate.
class PendingNotification {
  const PendingNotification({
    required this.entityType,
    required this.entityId,
    required this.triggerType,
    required this.title,
    required this.body,
    required this.at,
  });

  final String entityType;
  final String entityId;
  final NotificationTriggerType triggerType;
  final String title;
  final String body;
  final DateTime at;

  int get id => notificationId(
        entityType: entityType,
        entityId: entityId,
        triggerType: triggerType,
      );
}

/// Deterministic, collision-resistant ID for a (entityType, entityId,
/// triggerType) triple. flutter_local_notifications IDs are 32-bit ints;
/// Dart's `Object.hashCode` isn't guaranteed stable across isolates or
/// runs, so this hashes the composite key by hand (FNV-1a) instead.
int notificationId({
  required String entityType,
  required String entityId,
  required NotificationTriggerType triggerType,
}) {
  final key = '$entityType|$entityId|${triggerType.name}';
  var hash = 0x811C9DC5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF; // stay positive — plugin IDs are signed int32
}

/// A feature's current desired set of reminders (e.g. "every document
/// expiring within its warning window"). Each trigger type registers one
/// of these with [NotificationService]; M5.1 builds the registry, M5.2/
/// M5.3 populate it.
typedef PendingNotificationsSource = Future<List<PendingNotification>>
    Function();

/// Thin wrapper over the plugin so nothing outside this file — and
/// nothing in a test — ever touches a real OS notification tray. Tests
/// provide a fake implementation via [notificationSchedulerProvider].
abstract class NotificationScheduler {
  Future<bool> requestPermission();
  Future<void> zonedSchedule(PendingNotification notification);
  Future<void> cancel(int id);
  Future<void> cancelAll();
}

/// Does nothing, never throws. This is the default [notificationSchedulerProvider]
/// value rather than [sharedPreferencesProvider]'s "throw until overridden"
/// pattern, deliberately: `app.dart` reads `notificationWiringProvider` on
/// every build (unconditionally, so reminders stay in sync from cold
/// start), which means *every* widget test that builds the full app —
/// most do, via routing — would otherwise need to override the scheduler
/// even when the test has nothing to do with notifications. A missing
/// SharedPreferences instance has no safe default (something would read
/// wrong data silently); a missing notification scheduler safely doing
/// nothing is fine, matching the "degrade, don't block" rule this file
/// already applies to plugin init and permission requests.
class NoopNotificationScheduler implements NotificationScheduler {
  const NoopNotificationScheduler();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> zonedSchedule(PendingNotification notification) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}

/// Overridden at startup with the real plugin-backed instance (main.dart);
/// tests that specifically exercise notification behavior override this
/// with a recording fake (see `FakeNotificationScheduler` in
/// `notification_service_test.dart`). Every other test gets the safe
/// no-op default above for free.
final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => const NoopNotificationScheduler(),
);

/// Owns the registry of [PendingNotificationsSource]s and the resync that
/// keeps scheduled OS alarms in sync with local data. Business logic only
/// (ID derivation, past-time filtering, the master-toggle gate) — no
/// widget/BuildContext coupling, testable with a fake scheduler.
class NotificationService {
  NotificationService(this._scheduler, this._clock);

  final NotificationScheduler _scheduler;
  final DateTime Function() _clock;
  final List<PendingNotificationsSource> _sources = [];

  Future<bool> requestPermission() => _scheduler.requestPermission();

  /// Registers a feature's reminder source. Call once per trigger type at
  /// app wiring time (each of M5.2/M5.3 does this for its own type).
  void registerSource(PendingNotificationsSource source) {
    _sources.add(source);
  }

  /// Cancels every currently-scheduled reminder and reschedules from every
  /// registered source, skipping anything already in the past (the clock
  /// may have moved on since a source computed [PendingNotification.at]).
  /// Call on app launch — this is the "boot receiver" substitute described
  /// in the M5 plan doc — and again whenever underlying data changes.
  ///
  /// [masterEnabled] is the settings master toggle; per-type toggles are
  /// each source's own responsibility (a disabled type simply contributes
  /// nothing, rather than this service knowing about settings keys).
  Future<void> resyncAll({required bool masterEnabled}) async {
    await _scheduler.cancelAll();
    if (!masterEnabled) return;
    final now = _clock();
    for (final source in _sources) {
      final pending = await source();
      for (final notification in pending) {
        if (notification.at.isAfter(now)) {
          await _scheduler.zonedSchedule(notification);
        }
      }
    }
  }

  Future<void> cancel(PendingNotification notification) =>
      _scheduler.cancel(notification.id);
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    ref.watch(notificationSchedulerProvider),
    ref.watch(clockProvider),
  );
});
