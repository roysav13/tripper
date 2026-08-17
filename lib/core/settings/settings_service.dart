import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeMode = 'theme_mode';
const _kVaultLock = 'vault_lock_enabled';
const _kHasExported = 'has_exported_backup';
const _kNotificationsMaster = 'notifications_master_enabled';
const _kNotifyDocExpiry = 'notifications_doc_expiry_enabled';
const _kNotifyTripCountdown = 'notifications_trip_countdown_enabled';
const _kNotifyCheckIn = 'notifications_check_in_enabled';
const _kDocExpiryNoticeDays = 'document_expiry_notice_days';
const _kHomeCurrency = 'home_currency';
const _kAppLocale = 'app_locale';
const _kNearbyPlacesEnabled = 'nearby_places_enabled';
const _kNearbyApiCallCount = 'nearby_api_call_count';

/// Overridden at startup with the real instance (main.dart).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('SharedPreferences not initialised'),
);

/// Defaults to light, independent of the system setting. The redesign's
/// design spec (docs/SPEC.md §4.2) now describes dark as the primary mode
/// with light as a fully-designed true alternate, but this default has not
/// been flipped to match — switching it is a real, user-visible product
/// decision left for a later phase, not something this token-only
/// foundation phase decided.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref.read(sharedPreferencesProvider).getString(_kThemeMode);
    return switch (stored) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(
          _kThemeMode,
          switch (mode) {
            ThemeMode.dark => 'dark',
            ThemeMode.system => 'system',
            ThemeMode.light => 'light',
          },
        );
  }

  Future<void> toggle() =>
      set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// English by default — the app doesn't follow system locale (manual
/// picker only, this round — see the design spec's "Out of scope").
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final stored = ref.read(sharedPreferencesProvider).getString(_kAppLocale);
    return stored == 'he' ? const Locale('he') : const Locale('en');
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kAppLocale, locale.languageCode);
  }
}

final localeProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);

/// Biometric gate on the vault; on by default (SPEC M2).
class VaultLockSettingController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_kVaultLock) ?? true;

  Future<void> set({required bool enabled}) async {
    state = enabled;
    await ref.read(sharedPreferencesProvider).setBool(_kVaultLock, enabled);
  }
}

final vaultLockEnabledProvider =
    NotifierProvider<VaultLockSettingController, bool>(
  VaultLockSettingController.new,
);

/// Whether a backup export has ever completed (M4.5 reminder banner — local
/// data is lost on uninstall until Phase 3 cloud sync, so this nudges the
/// user toward the one safety net that exists today).
class HasExportedController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_kHasExported) ?? false;

  Future<void> markExported() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_kHasExported, true);
  }
}

final hasExportedProvider =
    NotifierProvider<HasExportedController, bool>(HasExportedController.new);

/// Master switch for the M5.1 local-notifications subsystem — off cancels
/// every scheduled reminder outright (see `NotificationService.resyncAll`),
/// not just hides them in-app. Defaults on: these are local-only, low-
/// friction reminders, not the kind of sensitive/battery-costly feature
/// (like M6 GPS tracking) that warrants an off-by-default stance.
class NotificationsMasterController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_kNotificationsMaster) ??
      true;

  Future<void> set({required bool enabled}) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kNotificationsMaster, enabled);
  }
}

final notificationsMasterEnabledProvider =
    NotifierProvider<NotificationsMasterController, bool>(
  NotificationsMasterController.new,
);

/// Per-type toggles (SPEC §3.2.1). Each trigger's own source (M5.2/M5.3)
/// checks its toggle before contributing to the resync — this service
/// layer just stores the bit, same shape as the other toggles above.
class DocExpiryNotificationsController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_kNotifyDocExpiry) ?? true;

  Future<void> set({required bool enabled}) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kNotifyDocExpiry, enabled);
  }
}

final docExpiryNotificationsEnabledProvider =
    NotifierProvider<DocExpiryNotificationsController, bool>(
  DocExpiryNotificationsController.new,
);

class TripCountdownNotificationsController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_kNotifyTripCountdown) ??
      true;

  Future<void> set({required bool enabled}) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kNotifyTripCountdown, enabled);
  }
}

final tripCountdownNotificationsEnabledProvider =
    NotifierProvider<TripCountdownNotificationsController, bool>(
  TripCountdownNotificationsController.new,
);

class CheckInNotificationsController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_kNotifyCheckIn) ?? true;

  Future<void> set({required bool enabled}) async {
    state = enabled;
    await ref.read(sharedPreferencesProvider).setBool(_kNotifyCheckIn, enabled);
  }
}

final checkInNotificationsEnabledProvider =
    NotifierProvider<CheckInNotificationsController, bool>(
  CheckInNotificationsController.new,
);

/// How many days before a document's expiry date counts as "coming up" for
/// notice purposes (the M5.2 expiry notification's fire window) — user-
/// configurable per the 2026-07-23 request. Default mirrors the previous
/// fixed `kExpiryBufferDays` in `expiry_checker.dart` (90) so behavior
/// doesn't silently change for anyone until they touch the setting.
/// Not imported from that file directly — `core/` doesn't depend on
/// `features/` — so if that constant ever moves, update this default too.
/// 0 means "no advance notice" (only counts once actually expired).
const kDefaultDocExpiryNoticeDays = 90;

class DocExpiryNoticeDaysController extends Notifier<int> {
  @override
  int build() =>
      ref.read(sharedPreferencesProvider).getInt(_kDocExpiryNoticeDays) ??
      kDefaultDocExpiryNoticeDays;

  Future<void> set(int days) async {
    final clamped = days < 0 ? 0 : days;
    state = clamped;
    await ref
        .read(sharedPreferencesProvider)
        .setInt(_kDocExpiryNoticeDays, clamped);
  }
}

final documentExpiryNoticeDaysProvider =
    NotifierProvider<DocExpiryNoticeDaysController, int>(
  DocExpiryNoticeDaysController.new,
);

/// The currency mixed-currency trip totals are converted into (M5.5b).
/// Empty string = conversion off: totals then show one line per currency
/// only, which is the honest fallback and needs no network at all.
class HomeCurrencyController extends Notifier<String> {
  @override
  String build() =>
      ref.read(sharedPreferencesProvider).getString(_kHomeCurrency) ?? '';

  Future<void> set(String currency) async {
    final normalized = currency.trim().toUpperCase();
    state = normalized;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kHomeCurrency, normalized);
  }
}

final homeCurrencyProvider = NotifierProvider<HomeCurrencyController, String>(
  HomeCurrencyController.new,
);

// The withdrawn Plan feature also stored dismissed timeline suggestions
// under the `itinerary_hidden_anchors` key. That controller is gone; the
// stale key is left untouched on devices that have one, since deleting
// it buys nothing and a revived feature would want it back.

/// Master gate for the Near By feature (M5-phase2a §5.10) — off by
/// default, since this is the one feature in the app that always costs a
/// real network call and has no offline value. Every nearby-fetch code
/// path checks this itself (not just the UI that shows/hides the entry
/// point), so "off" is a real guarantee.
class NearbyPlacesEnabledController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_kNearbyPlacesEnabled) ??
      false;

  Future<void> set({required bool enabled}) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kNearbyPlacesEnabled, enabled);
  }
}

final nearbyPlacesEnabledProvider =
    NotifierProvider<NearbyPlacesEnabledController, bool>(
  NearbyPlacesEnabledController.new,
);

/// Lifetime count of real `searchNearby` HTTP calls this install has made
/// — incremented once per real fetch, never on a cache hit. No reset
/// action in v1; shown in Settings so a cost is visible before it's a
/// surprise, not to budget against.
class NearbyApiCallCountController extends Notifier<int> {
  @override
  int build() =>
      ref.read(sharedPreferencesProvider).getInt(_kNearbyApiCallCount) ?? 0;

  Future<void> increment() async {
    state = state + 1;
    await ref
        .read(sharedPreferencesProvider)
        .setInt(_kNearbyApiCallCount, state);
  }
}

final nearbyApiCallCountProvider =
    NotifierProvider<NearbyApiCallCountController, int>(
  NearbyApiCallCountController.new,
);
