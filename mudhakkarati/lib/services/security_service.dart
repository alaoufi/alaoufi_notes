import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'encryption_service.dart';

/// قفل التطبيق برقم سري + دعم البصمة. كل شيء محلي.
class SecurityService {
  SecurityService._();
  static final SecurityService instance = SecurityService._();

  static const _kPinHash = 'pin_hash';
  static const _kPinSalt = 'pin_salt';
  static const _kLockEnabled = 'lock_enabled';
  static const _kBiometric = 'biometric_enabled';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _auth = LocalAuthentication();

  Future<bool> isLockEnabled() async =>
      (await _storage.read(key: _kLockEnabled)) == 'true';

  Future<bool> isBiometricEnabled() async =>
      (await _storage.read(key: _kBiometric)) == 'true';

  Future<bool> hasPin() async => (await _storage.read(key: _kPinHash)) != null;

  Future<void> setPin(String pin) async {
    const salt = 'mudhakkarati_pin';
    final hash = EncryptionService.instance.hashSecret(pin, salt);
    await _storage.write(key: _kPinSalt, value: salt);
    await _storage.write(key: _kPinHash, value: hash);
    await _storage.write(key: _kLockEnabled, value: 'true');
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _kPinSalt) ?? 'mudhakkarati_pin';
    final stored = await _storage.read(key: _kPinHash);
    if (stored == null) return false;
    return EncryptionService.instance.hashSecret(pin, salt) == stored;
  }

  Future<void> disableLock() async {
    await _storage.write(key: _kLockEnabled, value: 'false');
    await _storage.write(key: _kBiometric, value: 'false');
    await _storage.delete(key: _kPinHash);
    await _storage.delete(key: _kPinSalt);
  }

  Future<void> setBiometric(bool enabled) async {
    await _storage.write(key: _kBiometric, value: enabled ? 'true' : 'false');
  }

  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
