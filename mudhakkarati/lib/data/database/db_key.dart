import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// يدير مفتاح تشفير قاعدة البيانات (SQLCipher) في التخزين الآمن للجهاز.
///
/// المفتاح عشوائي 256-بت يُولَّد مرة واحدة ويُحفظ مشفّرًا في Keystore.
class DbKeyManager {
  DbKeyManager._();
  static final DbKeyManager instance = DbKeyManager._();

  static const _kKey = 'db_cipher_key';
  static const _kMigrated = 'db_encrypted_v1';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// المفتاح الحالي، أو يُنشئ واحدًا جديدًا إن لم يوجد.
  Future<String> getOrCreateKey() async {
    final existing = await _storage.read(key: _kKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    final key = base64UrlEncode(bytes);
    await _storage.write(key: _kKey, value: key);
    return key;
  }

  /// ضبط المفتاح يدويًا (عند الاستعادة من نسخة احتياطية تحمل مفتاحها).
  Future<void> setKey(String key) async {
    await _storage.write(key: _kKey, value: key);
  }

  Future<bool> isMigrated() async =>
      (await _storage.read(key: _kMigrated)) == 'true';

  Future<void> markMigrated() async {
    await _storage.write(key: _kMigrated, value: 'true');
  }

  Future<void> clearMigrated() async {
    await _storage.delete(key: _kMigrated);
  }
}
