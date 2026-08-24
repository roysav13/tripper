import 'vault_lock.dart';

/// Browsers expose no equivalent of `local_auth`: WebAuthn can verify a
/// previously *registered* credential, but it cannot answer "is the
/// person holding this device the owner" for a local-only app with no
/// server to register against. Rather than fake a challenge, the web
/// build treats the vault as unlocked — the same answer this app already
/// gives for an Android device with no lock screen configured — and
/// `kSupportsBiometricLock` lets Settings say so instead of offering a
/// toggle that would do nothing.
BiometricAuthenticator createBiometricAuthenticator() => (reason) async => true;

const kSupportsBiometricLock = false;
