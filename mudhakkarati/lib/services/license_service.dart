import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// تفعيل التطبيق المربوط بالجهاز (يعمل دون إنترنت).
///
/// - لكل تثبيت معرّف جهاز عشوائي ثابت (Device ID) يُعرض للمستخدم.
/// - رمز التفعيل توقيع Ed25519 على معرّف الجهاز، يولّده المالك بمفتاحه الخاص.
/// - التطبيق يتحقق من التوقيع بمفتاح عام مدمج → لا يمكن تزوير رموز،
///   والرمز يعمل على جهاز واحد فقط، ونشر الـAPK بلا فائدة.
class LicenseService {
  LicenseService._();
  static final LicenseService instance = LicenseService._();

  // المفتاح العام للمالك (Base64) — يُستبدل بمفتاحك بعد توليده بالأداة.
  // التحقق فقط؛ لا يمكن توليد رموز منه.
  static const String _publicKeyB64 = 'REPLACE_WITH_YOUR_PUBLIC_KEY';

  static const _kDeviceId = 'lic_device_id';
  static const _kActivated = 'lic_activated';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _ed = Ed25519();

  /// هل فُعّل التطبيق على هذا الجهاز؟ (يعتبر مفعّلًا إن لم يُضبط مفتاح عام بعد).
  Future<bool> isActivated() async {
    if (!_keyConfigured) return true; // وضع التطوير: لا قفل قبل ضبط المفتاح.
    return (await _storage.read(key: _kActivated)) == 'true';
  }

  bool get _keyConfigured =>
      _publicKeyB64.isNotEmpty && !_publicKeyB64.startsWith('REPLACE_');

  /// معرّف الجهاز (يُنشأ مرة ويثبت). يُعرض للمستخدم بصيغة مقروءة.
  Future<String> deviceId() async {
    var id = await _storage.read(key: _kDeviceId);
    if (id == null || id.isEmpty) {
      final rnd = Random.secure();
      final bytes = List<int>.generate(10, (_) => rnd.nextInt(256));
      id = base32(bytes); // 16 حرفًا تقريبًا.
      await _storage.write(key: _kDeviceId, value: id);
    }
    return id;
  }

  /// معرّف الجهاز مُجمّلًا بمجموعات من 4 (XXXX-XXXX-...).
  Future<String> deviceIdPretty() async {
    final id = await deviceId();
    final out = StringBuffer();
    for (var i = 0; i < id.length; i++) {
      if (i > 0 && i % 4 == 0) out.write('-');
      out.write(id[i]);
    }
    return out.toString();
  }

  /// يتحقق من رمز التفعيل (Base64 لتوقيع Ed25519 على معرّف الجهاز).
  /// عند النجاح يحفظ حالة التفعيل ويعيد true.
  Future<bool> tryActivate(String code) async {
    if (!_keyConfigured) return true;
    try {
      final id = await deviceId();
      final sig = base64Decode(_normalize(code));
      final pub = SimplePublicKey(base64Decode(_publicKeyB64),
          type: KeyPairType.ed25519);
      final ok = await _ed.verify(
        utf8.encode(id),
        signature: Signature(sig, publicKey: pub),
      );
      if (ok) await _storage.write(key: _kActivated, value: 'true');
      return ok;
    } catch (_) {
      return false;
    }
  }

  String _normalize(String code) {
    var c = code.trim().replaceAll(RegExp(r'\s|-'), '');
    final pad = c.length % 4;
    if (pad != 0) c = c.padRight(c.length + (4 - pad), '=');
    return c;
  }

  /// ترميز Base32 (Crockford-ish) بلا حروف ملتبسة.
  static String base32(List<int> bytes) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    var bits = 0, value = 0;
    final out = StringBuffer();
    for (final b in bytes) {
      value = (value << 8) | b;
      bits += 8;
      while (bits >= 5) {
        out.write(alphabet[(value >> (bits - 5)) & 31]);
        bits -= 5;
      }
    }
    if (bits > 0) out.write(alphabet[(value << (5 - bits)) & 31]);
    return out.toString();
  }
}
