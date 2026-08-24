import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/notifications/notification_service.dart';
import 'core/settings/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Drawing behind the system bars is an Android concept, and the web
  // engine has no handler for this platform message — awaiting it there
  // rejects before runApp, which is a blank page rather than a degraded
  // one. A browser gives us its own chrome regardless.
  if (!kIsWeb) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  // Loaded before runApp so the first frame already has the right theme.
  final prefs = await SharedPreferences.getInstance();

  // Never throws (see doc comment) — safe to run before runApp even if a
  // device's notification setup is unusual. On the web this resolves to
  // the no-op scheduler; browsers cannot fire a reminder while the app
  // is closed.
  final scheduler = await createNotificationScheduler();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationSchedulerProvider.overrideWithValue(scheduler),
      ],
      child: const TripperApp(),
    ),
  );
}
