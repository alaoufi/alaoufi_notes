# النظام العالميّ للتفعيل (Universal License) — مفتاح واحد لكلّ التطبيقات

نظام تفعيل **واحد** يصلح لأيّ تطبيق دون تخصيص: المالك يُدخل **رقم الجهاز + المدّة**
في المولّد فيخرج كود، وأيّ تطبيق يضع **المفتاح العامّ العالميّ** أدناه ويتبع القاعدة
يقبل الكود ويفتح حسب المدّة. سهولة قصوى مع قوّة Ed25519 الكاملة.

> **للمطوّر:** تحتاج **المفتاح العامّ** فقط (أدناه). لا تحتاج — ولن تُعطى —
> المفتاح الخاصّ؛ فهو في مولّد المالك وحده. بدونه لا يمكن تزوير أكواد.

---

## 1) الثوابت العالميّة (انسخها كما هي)

| العنصر | القيمة |
|---|---|
| بادئة الصيغة `prefix` | `UNIV1` |
| المفتاح العامّ (Base64) | `0JXPjbbPjczfYbYxl+jy1vOVcsEJT+CPbUIQgXNCStU=` |
| ملح اشتقاق معرّف الجهاز | `alaoufi:` |
| نوع التعمية | Ed25519 (RFC 8032) |
| صيغة الكود | 66 بايت (مدّة 2 + توقيع 64) → 106 حرف Base32 مخصّص |

النصّ المُوقَّع: `UNIV1|<رقم الجهاز المطبّع>|<المدّة بالأيام>` (0 = دائم).

---

## 2) القاعدة (المعادلة) — مطابِقة لكلّ التطبيقات

```
معرّف الجهاز = base32( sha256("alaoufi:" + ANDROID_ID)[0:10] )   // 16 حرفًا
النصّ        = "UNIV1|" + معرّف_الجهاز + "|" + المدّة
الكود        = group5( base32( [durHi, durLo] ++ Ed25519_sign(النصّ, masterالسرّي) ) )
التحقّق      = Ed25519_verify(النصّ, التوقيع, المفتاح_العامّ_العالميّ)
المدّة       = expiry = activatedAt + days*86400000 ، مع حارس ساعة (راجع §4)
```

---

## 3) «كود واحد يفتح أيّ تطبيق» — شرطان

ليصلح **نفس الكود** على عدّة تطبيقات على نفس الجهاز:
1. **توقيع كلّ تطبيقاتك بنفس مفتاح التوقيع (keystore واحد).** لأن `ANDROID_ID`
   يختلف باختلاف مفتاح التوقيع ⇒ يجب توحيده ليتطابق «رقم الجهاز» عبر التطبيقات.
2. **نفس ملح المعرّف `alaoufi:`** في كلّ التطبيقات (مضمَّن في القالب أدناه).

عند تحقّق الشرطين: رقم الجهاز واحد عبر كلّ تطبيقاتك ⇒ كود واحد يفتحها كلّها للمدّة
المحدّدة. إن اختلف مفتاح التوقيع لتطبيق، يبقى النظام يعمل لكن تولّد كودًا لكلّ تطبيق
حسب رقم جهازه (المولّد نفسه يبقى عالميًّا — لا تخصيص فيه).

> ملاحظة: كون الكود يفتح كلّ التطبيقات ميزة مقصودة هنا (رخصة لكلّ منظومتك على
> الجهاز). إن أردت عزل كلّ تطبيق، استخدم بادئة/مفتاحًا خاصًّا لذلك التطبيق بدل العالميّ.

---

## 4) آلية المدّة (مطابِقة لكلّ التطبيقات)

```
السجلّ بعد التفعيل:  d=المدّة(0=دائم)، a=لحظة التفعيل(ms)، s=آخر وقت رُئي
عند كلّ فتح:
  expiry = a + d*86400000
  effNow = max(now, s)            // حارس: إرجاع الساعة لا يُمدّد
  if effNow > s: خزّن s = effNow
  d==0            ⇒ دائم
  effNow <  expiry ⇒ مفعّل، المتبقّي = ceil((expiry-effNow)/86400000)
  effNow >= expiry ⇒ منتهٍ ⇒ اقفل واطلب كودًا جديدًا
```

---

## 5) القالب الجاهز — `lib/services/license_service.dart`

يُوضع **كما هو** في أيّ تطبيق Flutter (لا تغيير مطلوب). الحزم المطلوبة:
`cryptography ^2.9.0`، `crypto ^3.0.3`، `android_id ^0.5.1`،
`device_info_plus ^12.4.0`، `flutter_secure_storage ^9.0.0`، `path_provider ^2.1.0`.

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:android_id/android_id.dart';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

enum LicenseState { disabled, none, active, expired }

class LicenseInfo {
  final LicenseState state;
  final bool permanent;
  final DateTime? expiry;
  final int daysLeft;
  const LicenseInfo(this.state, this.permanent, this.expiry, this.daysLeft);
}

class LicenseService {
  LicenseService._();
  static final LicenseService instance = LicenseService._();

  // ===== الثوابت العالميّة — نفسها في كلّ تطبيقاتك =====
  static const String _publicKeyB64 =
      '0JXPjbbPjczfYbYxl+jy1vOVcsEJT+CPbUIQgXNCStU=';
  static const String _msgPrefix = 'UNIV1';
  static const String _deviceSalt = 'alaoufi:'; // وحّده ليتطابق رقم الجهاز

  static const _kDeviceId = 'lic_device_id';
  static const _kRecord = 'lic_record';
  static const _licenseFile = '.alaoufi_license';
  static const _dayMs = 86400000;

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _ed = Ed25519();

  bool get _keyConfigured =>
      _publicKeyB64.isNotEmpty && !_publicKeyB64.startsWith('REPLACE_');

  // ---- معرّف الجهاز ----
  Future<String> deviceId() async {
    final cached = await _storage.read(key: _kDeviceId);
    if (cached != null && cached.isNotEmpty) return cached;
    String? raw = await _hardwareFingerprint();
    if (raw == null || raw.isEmpty) {
      final rnd = Random.secure();
      raw = base64Encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    }
    final digest = crypto.sha256.convert(utf8.encode('$_deviceSalt$raw'));
    final id = base32(digest.bytes.sublist(0, 10));
    await _storage.write(key: _kDeviceId, value: id);
    return id;
  }

  Future<String> deviceIdPretty() async {
    final id = await deviceId();
    final out = StringBuffer();
    for (var i = 0; i < id.length; i++) {
      if (i > 0 && i % 4 == 0) out.write('-');
      out.write(id[i]);
    }
    return out.toString();
  }

  Future<String?> _hardwareFingerprint() async {
    try {
      if (Platform.isAndroid) {
        final aid = await const AndroidId().getId();
        if (aid != null && aid.isNotEmpty) return aid;
      }
      if (Platform.isIOS) {
        final i = await DeviceInfoPlugin().iosInfo;
        return i.identifierForVendor;
      }
    } catch (_) {}
    return null;
  }

  // ---- الحالة والمدّة ----
  Future<bool> isActivated() async {
    final s = (await info()).state;
    return s == LicenseState.active || s == LicenseState.disabled;
  }

  Future<LicenseInfo> info() async {
    if (!_keyConfigured) {
      return const LicenseInfo(LicenseState.disabled, false, null, 0);
    }
    final rec = await _readRecord();
    if (rec == null) return const LicenseInfo(LicenseState.none, false, null, 0);

    final duration = rec['d'] as int; // 0 = دائم
    final activated = rec['a'] as int;
    final lastSeen = (rec['s'] as int?) ?? activated;

    final now = DateTime.now().millisecondsSinceEpoch;
    final effNow = now > lastSeen ? now : lastSeen; // حارس الساعة
    if (effNow != lastSeen) {
      rec['s'] = effNow;
      await _writeRecord(rec);
    }

    if (duration == 0) {
      return const LicenseInfo(LicenseState.active, true, null, 0);
    }
    final expiryMs = activated + duration * _dayMs;
    final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
    if (effNow < expiryMs) {
      final daysLeft = ((expiryMs - effNow) / _dayMs).ceil();
      return LicenseInfo(LicenseState.active, false, expiry, daysLeft);
    }
    return LicenseInfo(LicenseState.expired, false, expiry, 0);
  }

  // ---- التفعيل ----
  Future<bool> tryActivate(String code) async {
    if (!_keyConfigured) return true;
    try {
      final bytes = base32Decode(_normalizeKey(code));
      if (bytes.length != 66) return false; // مدّة(2) + توقيع(64)
      final duration = (bytes[0] << 8) | bytes[1];
      final sig = bytes.sublist(2);
      final id = await deviceId();
      final msg = utf8.encode('$_msgPrefix|$id|$duration');
      final pub = SimplePublicKey(base64Decode(_publicKeyB64),
          type: KeyPairType.ed25519);
      final ok =
          await _ed.verify(msg, signature: Signature(sig, publicKey: pub));
      if (!ok) return false;
      await _activate(duration);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _activate(int duration) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _writeRecord({'d': duration, 'a': now, 's': now});
  }

  Future<void> deactivate() async {
    await _storage.delete(key: _kRecord);
    try {
      final f = await _fileRef();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  // ---- التخزين ----
  Future<File> _fileRef() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_licenseFile');
  }

  Future<Map<String, dynamic>?> _readRecord() async {
    String? raw;
    try {
      raw = await _storage.read(key: _kRecord);
    } catch (_) {}
    if (raw == null || raw.isEmpty) {
      try {
        final f = await _fileRef();
        if (await f.exists()) {
          raw = await f.readAsString();
          if (raw.isNotEmpty) {
            try {
              await _storage.write(key: _kRecord, value: raw);
            } catch (_) {}
          }
        }
      } catch (_) {}
    }
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw);
      if (m is Map<String, dynamic>) return m;
    } catch (_) {}
    return null;
  }

  Future<void> _writeRecord(Map<String, dynamic> rec) async {
    final raw = jsonEncode(rec);
    try {
      await _storage.write(key: _kRecord, value: raw);
    } catch (_) {}
    try {
      final f = await _fileRef();
      await f.writeAsString(raw, flush: true);
    } catch (_) {}
  }

  // ---- ترميز Base32 مخصّص ----
  String _normalizeKey(String code) =>
      code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

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
      value &= (1 << bits) - 1;
    }
    if (bits > 0) out.write(_b32[(value << (5 - bits)) & 31]);
    return out.toString();
  }

  static List<int> base32Decode(String s) {
    var bits = 0, value = 0;
    final out = <int>[];
    for (final ch in s.split('')) {
      final idx = _b32.indexOf(ch);
      if (idx < 0) continue;
      value = (value << 5) | idx;
      bits += 5;
      if (bits >= 8) {
        out.add((value >> (bits - 8)) & 0xff);
        bits -= 8;
      }
      value &= (1 << bits) - 1;
    }
    return out;
  }
}
```

شاشة التفعيل: استخدم نفس `activation_gate.dart` الوارد في `MARAH_DEV_HANDOFF.md`
(لا يعتمد على اسم تطبيق)، ولُفّ الشاشة الرئيسية: `home: ActivationGate(child: Home())`.

---

## 6) متجهات اختبار (للتأكّد من تطابق التنفيذ)

بادئة `UNIV1`، المفتاح العالميّ، الناتج بلا شرطات (106 حرفًا):

| رقم الجهاز | المدّة | الكود الناتج |
|---|---|---|
| `TESTDEVICE234567` | 0 (دائم) | `AAANSJ2UELQ398JB5X4FPSV9DWUW3XSRP367RBVF9ASD7URBN55UTUBRMHWNYEQTL6HQLVS43XA5B3K7QK2ZU7FF4GX8PJB93BE4CKB2AJ` |
| `TESTDEVICE234567` | 30 | `AARLNZUCVGUA827D3FUBNPHB9ESX6KZX4EWUEM7NX7LU2CJ5XX4JPZSBUPAWUDNKH2TAP2P7992LQ99UNV9HP55BME68X8EM8FBU69UBAJ` |

إن أنتج تنفيذك نفس هذه السلاسل لنفس المدخلات (وبنفس المفتاح) فهو مطابق.

---

## 7) نسخة الويب/JavaScript (تحقّق + مدّة)

نفس `MARAH_DEV_HANDOFF.md §8` مع تغيير الثوابت فقط:
```js
const PREFIX = 'UNIV1';
const PUBKEY_B64 = '0JXPjbbPjczfYbYxl+jy1vOVcsEJT+CPbUIQgXNCStU=';
// معرّف الجهاز للويب: base32(sha256("alaoufi:"+raw)[0:10]) حيث raw مخزَّن في localStorage.
```

---

## 8) أمان

- لا تضع المفتاح الخاصّ (master Seed) في أيّ تطبيق أو كود ويب — المفتاح العامّ فقط.
- المفتاح العامّ نشرُه آمن (لا يولّد أكواد).
- كود واحد يفتح كلّ التطبيقات المشتركة في المفتاح على الجهاز نفسه (مقصود). إن أردت
  عزل تطبيق، أعطه بادئة/مفتاحًا خاصًّا (مثل مذكراتي/مراح) بدل العالميّ.
- على أندرويد: رقم الجهاز ثابت عبر التحديث/إعادة التثبيت (نفس مفتاح التوقيع)،
  ويتغيّر بضبط المصنع أو اختلاف مفتاح التوقيع.
```
