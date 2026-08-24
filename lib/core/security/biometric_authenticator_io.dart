import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'vault_lock.dart';

/// Biometric with device-PIN fallback. Devices without any lock screen
/// open freely (documented SPEC decision).
BiometricAuthenticator createBiometricAuthenticator() {
  final auth = LocalAuthentication();
  return (reason) async {
    try {
      final supported = await auth.isDeviceSupported();
      if (!supported) return true;
      return await auth.authenticate(localizedReason: reason);
    } on PlatformException {
      return false;
    }
  };
}

/// Whether this platform can actually challenge the user.
const kSupportsBiometricLock = true;
