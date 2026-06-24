import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// ترميز/توليد رموز التفعيل — **يجب أن يطابق** ما يتحقّق منه التطبيق في
/// `lib/services/license_service.dart` (نفس الصيغة والبادئة والـBase32).
class LicenseCodec {
  LicenseCodec._();

  static const String msgPrefix = 'MDKL1';
  static final _ed = Ed25519();

  /// يولّد رمز تفعيل لجهاز ومدّة معيّنة، موقّعًا بمفتاح المالك الخاصّ (Seed).
  ///
  /// [deviceId]: معرّف الجهاز كما يعرضه التطبيق (تُزال الشرطات والمسافات).
  /// [durationDays]: عدد الأيام، أو 0 لترخيص **دائم**.
  /// [seed]: 32 بايت (المفتاح الخاصّ للمالك).
  /// [prefix]: بادئة صيغة الرسالة الخاصّة بكلّ تطبيق (يجب أن تطابق `_msgPrefix`
  /// في ذلك التطبيق). الافتراضي [msgPrefix] لتطبيق «مذكراتي».
  static Future<String> generate({
    required String deviceId,
    required int durationDays,
    required List<int> seed,
    String prefix = msgPrefix,
  }) async {
    final id = _normalizeId(deviceId);
    final dur = durationDays.clamp(0, 65535);
    final kp = await _ed.newKeyPairFromSeed(seed);
    final msg = utf8.encode('$prefix|$id|$dur');
    final sig = await _ed.sign(msg, keyPair: kp);
    final bytes = <int>[(dur >> 8) & 0xff, dur & 0xff, ...sig.bytes];
    return _group(base32(bytes));
  }

  /// المفتاح العامّ المشتقّ من المفتاح الخاصّ (Base64) — لمطابقته بالمدمج بالتطبيق.
  static Future<String> publicKeyB64(List<int> seed) async {
    final kp = await _ed.newKeyPairFromSeed(seed);
    final pub = await kp.extractPublicKey();
    return base64Encode(pub.bytes);
  }

  /// يولّد زوج مفاتيح جديدًا: يعيد (seedHex, publicKeyB64).
  static Future<({String seedHex, String publicKeyB64})> newKeyPair() async {
    final kp = await _ed.newKeyPair();
    final seed = await kp.extractPrivateKeyBytes();
    final pub = await kp.extractPublicKey();
    return (
      seedHex: seed.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      publicKeyB64: base64Encode(pub.bytes),
    );
  }

  // نُكبّر ونحذف الفواصل فقط — دون إبدال حروف (كي يطابق معرّف الجهاز تمامًا).
  static String _normalizeId(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// جمّع الرمز بمجموعات من 5 لسهولة القراءة (تُزال عند الإدخال في التطبيق).
  static String _group(String s) {
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && i % 5 == 0) out.write('-');
      out.write(s[i]);
    }
    return out.toString();
  }

  static const _b32 = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String base32(List<int> bytes) {
    var bits = 0, value = 0;
    final out = StringBuffer();
    for (final b in bytes) {
      value = (value << 8) | b;
      bits += 8;
      while (bits >= 5) {
        out.write(_b32[(value >> (bits - 5)) & 31]);
        bits -= 5;
      }
      value &= (1 << bits) - 1; // أبقِ البتات المتبقّية فقط (تفادي تجاوز 64-بت).
    }
    if (bits > 0) out.write(_b32[(value << (5 - bits)) & 31]);
    return out.toString();
  }
}
