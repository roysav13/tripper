import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/core/notifications/notification_service.dart';

/// Records every call instead of touching a real OS notification tray —
/// per CLAUDE.md hard rule 5 ("no real network/OS side effects in tests"
/// applied to the notification plugin the same way it applies to network).
class FakeNotificationScheduler implements NotificationScheduler {
  final List<PendingNotification> scheduled = [];
  final List<int> cancelledIds = [];
  int cancelAllCalls = 0;
  bool permissionGranted = true;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> zonedSchedule(PendingNotification notification) async {
    scheduled.add(notification);
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    scheduled.clear();
  }
}

void main() {
  group('notificationId', () {
    test('is deterministic for the same triple', () {
      final a = notificationId(
        entityType: 'document',
        entityId: 'doc-1',
        triggerType: NotificationTriggerType.documentExpiry,
      );
      final b = notificationId(
        entityType: 'document',
        entityId: 'doc-1',
        triggerType: NotificationTriggerType.documentExpiry,
      );
      expect(a, b);
    });

    test('differs across entity id, entity type, and trigger type', () {
      final base = notificationId(
        entityType: 'document',
        entityId: 'doc-1',
        triggerType: NotificationTriggerType.documentExpiry,
      );
      final diffEntity = notificationId(
        entityType: 'document',
        entityId: 'doc-2',
        triggerType: NotificationTriggerType.documentExpiry,
      );
      final diffType = notificationId(
        entityType: 'trip',
        entityId: 'doc-1',
        triggerType: NotificationTriggerType.documentExpiry,
      );
      final diffTrigger = notificationId(
        entityType: 'document',
        entityId: 'doc-1',
        triggerType: NotificationTriggerType.checkInOpens,
      );
      expect({base, diffEntity, diffType, diffTrigger}.length, 4);
    });

    test(
        're-scheduling the same reminder reuses the same id (replace, not '
        'stack)', () {
      final n1 = PendingNotification(
        entityType: 'document',
        entityId: 'doc-1',
        triggerType: NotificationTriggerType.documentExpiry,
        title: 'Passport expiring',
        body: 'first save',
        at: DateTime(2026, 8, 1),
      );
      final n2 = PendingNotification(
        entityType: 'document',
        entityId: 'doc-1',
        triggerType: NotificationTriggerType.documentExpiry,
        title: 'Passport expiring',
        body: 'edited save, different body/time',
        at: DateTime(2026, 8, 5),
      );
      expect(n1.id, n2.id);
    });

    test('stays a positive 32-bit int across many inputs', () {
      for (var i = 0; i < 500; i++) {
        final id = notificationId(
          entityType: 'document',
          entityId: 'doc-$i',
          triggerType: NotificationTriggerType.values[i % 3],
        );
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });
  });

  group('NotificationService.resyncAll', () {
    late FakeNotificationScheduler scheduler;
    final now = DateTime(2026, 7, 23, 12);

    PendingNotification notificationAt(DateTime at, {String id = 'doc-1'}) {
      return PendingNotification(
        entityType: 'document',
        entityId: id,
        triggerType: NotificationTriggerType.documentExpiry,
        title: 'title',
        body: 'body',
        at: at,
      );
    }

    setUp(() {
      scheduler = FakeNotificationScheduler();
    });

    test('always cancels everything first, even when master is off', () async {
      final service = NotificationService(scheduler, () => now);
      await service.resyncAll(masterEnabled: false);
      expect(scheduler.cancelAllCalls, 1);
      expect(scheduler.scheduled, isEmpty);
    });

    test(
        'schedules nothing when master is off, even with sources '
        'registered', () async {
      final service = NotificationService(scheduler, () => now);
      service.registerSource(
        () async => [notificationAt(now.add(const Duration(days: 1)))],
      );
      await service.resyncAll(masterEnabled: false);
      expect(scheduler.scheduled, isEmpty);
    });

    test('schedules future reminders from every registered source', () async {
      final service = NotificationService(scheduler, () => now);
      service.registerSource(
        () async => [
          notificationAt(now.add(const Duration(days: 1)), id: 'doc-1'),
        ],
      );
      service.registerSource(
        () async => [
          notificationAt(now.add(const Duration(days: 2)), id: 'doc-2'),
        ],
      );
      await service.resyncAll(masterEnabled: true);
      expect(scheduler.scheduled, hasLength(2));
    });

    test('skips reminders whose time has already passed', () async {
      final service = NotificationService(scheduler, () => now);
      service.registerSource(
        () async => [
          notificationAt(now.subtract(const Duration(days: 1)), id: 'past'),
          notificationAt(now.add(const Duration(days: 1)), id: 'future'),
        ],
      );
      await service.resyncAll(masterEnabled: true);
      expect(scheduler.scheduled, hasLength(1));
      expect(scheduler.scheduled.single.entityId, 'future');
    });

    test(
        'cancels stale alarms before rescheduling — resync is a full '
        'replace, not an additive merge', () async {
      final service = NotificationService(scheduler, () => now);
      var callCount = 0;
      service.registerSource(() async {
        callCount++;
        // First call returns one reminder, second call returns a
        // different one — simulates data changing between resyncs.
        return [
          notificationAt(
            now.add(const Duration(days: 1)),
            id: callCount == 1 ? 'old' : 'new',
          ),
        ];
      });
      await service.resyncAll(masterEnabled: true);
      await service.resyncAll(masterEnabled: true);
      expect(scheduler.cancelAllCalls, 2);
      expect(scheduler.scheduled, hasLength(1));
      expect(scheduler.scheduled.single.entityId, 'new');
    });
  });

  group('NotificationService.requestPermission', () {
    test('delegates to the scheduler', () async {
      final scheduler = FakeNotificationScheduler()..permissionGranted = false;
      final service = NotificationService(scheduler, () => DateTime.now());
      expect(await service.requestPermission(), false);
    });
  });

  group('NotificationService.cancel', () {
    test('cancels a single notification by its derived id', () async {
      final scheduler = FakeNotificationScheduler();
      final service = NotificationService(scheduler, () => DateTime.now());
      final n = PendingNotification(
        entityType: 'trip',
        entityId: 'trip-1',
        triggerType: NotificationTriggerType.tripCountdown,
        title: 't',
        body: 'b',
        at: DateTime(2026, 8, 1),
      );
      await service.cancel(n);
      expect(scheduler.cancelledIds, [n.id]);
    });
  });
}
