import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/notification_wiring.dart';
import 'core/routing/app_router.dart';
import 'core/settings/settings_service.dart';
import 'core/theme/app_theme.dart';
import 'features/expenses/presentation/expense_providers.dart';
import 'l10n/app_localizations.dart';

class TripperApp extends ConsumerWidget {
  const TripperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reading this registers the M5.2 reminder sources and runs the first
    // resync exactly once (Riverpod caches Provider — later rebuilds are
    // a no-op read, not a re-registration). Value itself is unused.
    ref.watch(notificationWiringProvider);
    // Backfills stored currency conversions when rates are reachable;
    // a no-op when the home currency is unset or the device is offline.
    ref.watch(expenseConversionWiringProvider);
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );
  }
}
