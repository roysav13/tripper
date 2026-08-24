import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_service.dart';

/// Initialises the plugin and returns a scheduler bound to it. Never
/// throws — notification setup failing (missing OS component, odd OEM
/// build) must never block the app from starting, the same "degrade,
/// don't block" spirit as CLAUDE.md hard rule 4 applied to a device
/// capability instead of a network call.
Future<NotificationScheduler> createNotificationScheduler() async {
  final plugin = FlutterLocalNotificationsPlugin();
  try {
    tz_data.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(
      const InitializationSettings(android: androidInit),
    );
  } catch (_) {
    // Swallowed deliberately — see doc comment above.
    return const NoopNotificationScheduler();
  }
  return PluginNotificationScheduler(plugin);
}

class PluginNotificationScheduler implements NotificationScheduler {
  PluginNotificationScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _androidDetails = AndroidNotificationDetails(
    'tripper_reminders',
    'Trip reminders',
    channelDescription:
        'Document expiry, trip countdown, and check-in reminders',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  @override
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> zonedSchedule(PendingNotification notification) {
    return _plugin.zonedSchedule(
      notification.id,
      notification.title,
      notification.body,
      tz.TZDateTime.from(notification.at, tz.local),
      const NotificationDetails(android: _androidDetails),
      // Day-scale reminders, not minute-precision alarms — inexact
      // scheduling avoids requesting SCHEDULE_EXACT_ALARM entirely (see
      // AndroidManifest.xml comment).
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Required by this plugin version's signature; Android ignores it
      // (iOS-only concept — whether a fired notification's displayed time
      // is wall-clock or relative). absoluteTime is the correct choice on
      // every platform we ship since [notification.at] is already a real
      // wall-clock instant, not a relative offset.
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}

/// Whether this platform can schedule reminders at all.
const kSupportsScheduledNotifications = true;
