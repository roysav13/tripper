import 'notification_service.dart';

/// A web app can only post a notification while it is running, so the one
/// thing this subsystem exists for — reminding you about a document that
/// expires next month, while Tripper is closed — is not something a
/// browser can do. Rather than schedule alarms that silently never fire,
/// the web build keeps the no-op scheduler and Settings hides the
/// reminder toggles (see [kSupportsScheduledNotifications]).
Future<NotificationScheduler> createNotificationScheduler() async =>
    const NoopNotificationScheduler();

const kSupportsScheduledNotifications = false;
