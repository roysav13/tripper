import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';
import '../settings/settings_service.dart';
import 'biometric_authenticator_io.dart'
    if (dart.library.js_interop) 'biometric_authenticator_web.dart';

export 'biometric_authenticator_io.dart'
    if (dart.library.js_interop) 'biometric_authenticator_web.dart'
    show kSupportsBiometricLock;

/// Unlock session length — re-auth after this much time (SPEC M2).
const kVaultUnlockSession = Duration(minutes: 2);

/// Returns true when the user passed (or the device has no lock configured).
typedef BiometricAuthenticator = Future<bool> Function(String reason);

/// Production authenticator for whichever platform this is — see
/// `biometric_authenticator_io.dart` / `_web.dart`.
final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>(
  (ref) => createBiometricAuthenticator(),
);

/// State = unlocked right now. Session expiry is checked lazily on each
/// ensureUnlocked call against the injected clock.
class VaultLockController extends Notifier<bool> {
  DateTime? _unlockedUntil;

  @override
  bool build() => false;

  Future<bool> ensureUnlocked(String reason) async {
    // Disabled in settings -> vault opens freely.
    if (!ref.read(vaultLockEnabledProvider)) {
      state = true;
      return true;
    }
    final clock = ref.read(clockProvider);
    final now = clock();
    if (_unlockedUntil != null && now.isBefore(_unlockedUntil!)) {
      state = true;
      return true;
    }
    final ok = await ref.read(biometricAuthenticatorProvider)(reason);
    if (ok) {
      _unlockedUntil = clock().add(kVaultUnlockSession);
      state = true;
    } else {
      state = false;
    }
    return ok;
  }

  void lock() {
    _unlockedUntil = null;
    state = false;
  }
}

final vaultLockProvider =
    NotifierProvider<VaultLockController, bool>(VaultLockController.new);
