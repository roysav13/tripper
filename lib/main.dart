import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/notifications/notification_service.dart';
import 'core/settings/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Loaded before runApp so the first frame already has the right theme.
  final prefs = await SharedPreferences.getInstance();

  // Never throws (see doc comment) — safe to run before runApp even if a
  // device's notification setup is unusual.
  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  await initializeNotificationPlugin(notificationsPlugin);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationSchedulerProvider.overrideWithValue(
          PluginNotificationScheduler(notificationsPlugin),
        ),
      ],
      child: const TripperApp(),
    ),
  );
}
