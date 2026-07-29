import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/trips/domain/trip_notifications.dart';
import '../../features/trips/presentation/trip_providers.dart';
import '../../features/vault/domain/checkin_notifications.dart';
import '../../features/vault/domain/document.dart';
import '../../features/vault/domain/document_notifications.dart';
import '../../features/vault/presentation/document_providers.dart';
import '../../l10n/app_localizations.dart';
import '../database/database_provider.dart';
import '../settings/settings_service.dart';
import 'notification_service.dart';

/// Wires the M5.2 reminder sources into [notificationServiceProvider] and
/// keeps them resynced. Reading this provider once (`app.dart`) is enough
/// — Riverpod caches it, so registration and the `ref.listen` calls below
/// only ever run once per app session.
///
/// A `core/` file importing from `features/` is backwards for this
/// codebase (features depend on core, not the other way round) — this
/// file is the deliberate, single exception, because wiring has to live
/// somewhere that can see every feature's providers. It stays thin glue
/// only; the actual logic is the pure functions in each feature's
/// `domain/` layer (`document_notifications.dart`, `trip_notifications.dart`).
final notificationWiringProvider = Provider<void>((ref) {
  final service = ref.watch(notificationServiceProvider);

  // English only for now (CLAUDE.md hard rule 3 — Hebrew is a future
  // translation pass, SPEC §3.2.1). Notification text is generated
  // outside the widget tree, so it can't use AppLocalizations.of(context)
  // — lookupAppLocalizations is gen-l10n's context-free equivalent.
  final l10n = lookupAppLocalizations(const Locale('en'));

  service.registerSource(() async {
    if (!ref.read(docExpiryNotificationsEnabledProvider)) return const [];
    final docs = ref.read(vaultDocumentsProvider).valueOrNull ?? const [];
    final today = ref.read(clockProvider)();
    final noticeDays = ref.read(documentExpiryNoticeDaysProvider);
    return documentExpiryNotifications(
      docs,
      today,
      noticeDays: noticeDays,
      l10n: l10n,
    );
  });

  service.registerSource(() async {
    if (!ref.read(tripCountdownNotificationsEnabledProvider)) return const [];
    final trips = ref.read(tripListProvider).valueOrNull ?? const [];
    final docs = ref.read(vaultDocumentsProvider).valueOrNull ?? const [];
    final byTrip = <String, List<Document>>{};
    for (final doc in docs) {
      for (final tripId in doc.tripIds) {
        (byTrip[tripId] ??= []).add(doc);
      }
    }
    final today = ref.read(clockProvider)();
    return tripCountdownNotifications(trips, byTrip, today, l10n: l10n);
  });

  service.registerSource(() async {
    if (!ref.read(checkInNotificationsEnabledProvider)) return const [];
    final docs = ref.read(vaultDocumentsProvider).valueOrNull ?? const [];
    final today = ref.read(clockProvider)();
    return checkInOpensNotifications(docs, today, l10n: l10n);
  });

  Future<void> resync() async {
    try {
      await service.resyncAll(
        masterEnabled: ref.read(notificationsMasterEnabledProvider),
      );
    } catch (_) {
      // Never let a scheduling failure surface as a crash — same
      // degrade-don't-block spirit as initializeNotificationPlugin.
    }
  }

  // Re-derive and reschedule whenever the underlying data or any relevant
  // setting changes, instead of requiring a resync() call at every
  // document/trip mutation call site (easy to forget one).
  ref.listen(vaultDocumentsProvider, (_, __) => resync());
  ref.listen(tripListProvider, (_, __) => resync());
  ref.listen(notificationsMasterEnabledProvider, (_, __) => resync());
  ref.listen(docExpiryNotificationsEnabledProvider, (_, __) => resync());
  ref.listen(tripCountdownNotificationsEnabledProvider, (_, __) => resync());
  ref.listen(checkInNotificationsEnabledProvider, (_, __) => resync());
  ref.listen(documentExpiryNoticeDaysProvider, (_, __) => resync());

  // Request the OS notification permission, then do the initial resync —
  // sequenced, not run concurrently, so the very first zonedSchedule call
  // doesn't race the permission prompt's result. Android 13+ requires
  // POST_NOTIFICATIONS explicitly; every zonedSchedule call above is a
  // no-op on-device without it. This was the actual gap that made
  // nothing ever show up: the request/response plumbing existed
  // (NotificationService.requestPermission, PluginNotificationScheduler)
  // but nothing in the app ever called it (2026-07-23 fix). Fire-and-
  // forget from the provider's perspective — never block app startup on
  // the permission dialog's result.
  unawaited(() async {
    await service.requestPermission();
    await resync();
  }());
});
