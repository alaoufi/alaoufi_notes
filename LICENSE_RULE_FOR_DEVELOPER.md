# قاعدة التفعيل العالميّة — دليل المطوّر (مكتفٍ بذاته)

أعطِ هذا الملفّ للمطوّر فقط. يحوي **القاعدة والمعادلة + الكود الجاهز** لإضافة حماية
تفعيل (مربوطة بالجهاز، بمدّة صلاحية) لأيّ تطبيق، تعمل **دون إنترنت**. مفتاح واحد
عالميّ يصلح لكلّ التطبيقات.

> المطوّر يحتاج **المفتاح العامّ** فقط (أدناه). لا يحتاج المفتاح الخاصّ ولن يُعطاه.
> توليد الأكواد يتمّ في أداة المالك وحده.

---

## 0) ماذا تفعل (٤ خطوات)

1. أضف الحزم (§3) ثم ضع ملفّ `license_service.dart` (§4) و`activation_gate.dart` (§5)
   **كما هما بلا تعديل**.
2. لُفّ شاشتك الرئيسية: `home: ActivationGate(child: HomeScreen())` (§6).
3. لأندرويد: `minSdkVersion 26+`، ووقّع التطبيق بمفتاح التوقيع (keystore) الموحّد
   الذي يعطيك إيّاه المالك (مهمّ — §2).
4. لا شيء آخر. عند أوّل تشغيل تظهر شاشة تطلب رمز تفعيل؛ المالك يولّده من «رقم الجهاز».

---

## 1) الثوابت (مضمّنة في الكود — لا تغيّرها)

| العنصر | القيمة |
|---|---|
| المفتاح العامّ (Base64) | `0JXPjbbPjczfYbYxl+jy1vOVcsEJT+CPbUIQgXNCStU=` |
| بادئة الصيغة | `UNIV1` |
| ملح معرّف الجهاز | `alaoufi:` |
| التعمية | Ed25519 (RFC 8032) |
| الترميز | Base32 مخصّص `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` |

---

## 2) القاعدة والمعادلة (المفهوم)

```
1) معرّف الجهاز (يحسبه التطبيق ويعرضه للمستخدم):
   raw      = ANDROID_ID (أندرويد) / identifierForVendor (iOS)
   deviceId = base32( SHA256("alaoufi:" + raw)[0 .. 10) )      // 16 حرفًا

2) رمز التفعيل (يولّده المالك بالمفتاح الخاصّ):
   msg  = "UNIV1" + "|" + deviceId + "|" + duration            // duration: أيام، 0=دائم
   sig  = Ed25519_sign(msg, MASTER_PRIVATE)                     // 64 بايت
   pkt  = [ (duration>>8)&0xFF , duration&0xFF ] ++ sig          // 66 بايت
   code = group5( base32(pkt) )                                 // 106 حرف + شرطات

3) التحقّق (داخل التطبيق، بالمفتاح العامّ فقط):
   pkt = base32_decode( تطبيع(code) )      // تطبيع: أحرف كبيرة، احذف ما ليس [A-Z0-9]
   if len(pkt) != 66: فشل
   duration = (pkt[0]<<8) | pkt[1]
   sig      = pkt[2..66)
   msg      = "UNIV1|" + deviceId_المحلي + "|" + duration
   ok       = Ed25519_verify(msg, sig, MASTER_PUBLIC)

4) المدّة (تُفحص عند كلّ فتح):
   expiry = activatedAt + duration*86400000
   effNow = max(now, lastSeen)              // حارس: إرجاع الساعة لا يُمدّد المدّة
   duration==0            ⇒ دائم
   effNow <  expiry       ⇒ مفعّل (المتبقّي = ceil((expiry-effNow)/86400000))
   effNow >= expiry       ⇒ منتهٍ ⇒ اقفل واطلب رمزًا جديدًا
```

**ليصلح كود واحد لكلّ تطبيقاتك على نفس الجهاز:** وقّعها كلّها بنفس مفتاح التوقيع
(keystore واحد) واترك ملح المعرّف `alaoufi:` كما هو ⇒ يتطابق «رقم الجهاز» عبر
تطبيقاتك فيفتحها كود واحد. (لعزل تطبيق: أعطه بادئة/مفتاحًا خاصًّا بدل العالميّ.)

---

## 3) الحزم (`pubspec.yaml`)

```yaml
dependencies:
  cryptography: ^2.9.0
  crypto: ^3.0.3
  android_id: ^0.5.1
  device_info_plus: ^12.4.0
  flutter_secure_storage: ^9.0.0
  path_provider: ^2.1.0
```

---

## 4) `lib/services/license_service.dart` (انسخه كما هو)

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

  // ===== ثوابت عالميّة — نفسها في كلّ تطبيقاتك (لا تغيّرها) =====
  static const String _publicKeyB64 =
      '0JXPjbbPjczfYbYxl+jy1vOVcsEJT+CPbUIQgXNCStU=';
  static const String _msgPrefix = 'UNIV1';
  static const String _deviceSalt = 'alaoufi:';

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

  // ---- التخزين (آمن + ملفّ دائم احتياطًا) ----
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

---

## 5) `lib/security/activation_gate.dart` (انسخه كما هو)

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/license_service.dart';

/// بوابة التفعيل: تظهر قبل المحتوى إن لم يُفعّل أو انتهت المدّة، وتُعيد الفحص عند
/// عودة التطبيق للواجهة كي يُطبَّق الانتهاء فورًا.
class ActivationGate extends StatefulWidget {
  final Widget child;
  const ActivationGate({super.key, required this.child});

  @override
  State<ActivationGate> createState() => _ActivationGateState();
}

class _ActivationGateState extends State<ActivationGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  LicenseState _state = LicenseState.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_checking) _check();
  }

  Future<void> _check() async {
    final info = await LicenseService.instance.info();
    if (mounted) {
      setState(() {
        _state = info.state;
        _checking = false;
      });
    }
  }

  bool get _open =>
      _state == LicenseState.active || _state == LicenseState.disabled;

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_open) return widget.child;
    return _ActivationScreen(
      expired: _state == LicenseState.expired,
      onActivated: _check,
    );
  }
}

class _ActivationScreen extends StatefulWidget {
  final bool expired;
  final VoidCallback onActivated;
  const _ActivationScreen({required this.expired, required this.onActivated});

  @override
  State<_ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<_ActivationScreen> {
  final _codeCtrl = TextEditingController();
  String _deviceId = '...';
  bool _error = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    LicenseService.instance
        .deviceIdPretty()
        .then((v) => mounted ? setState(() => _deviceId = v) : null);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    setState(() {
      _busy = true;
      _error = false;
    });
    final ok = await LicenseService.instance.tryActivate(_codeCtrl.text);
    if (!mounted) return;
    if (ok) {
      widget.onActivated();
    } else {
      setState(() {
        _busy = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    widget.expired
                        ? Icons.lock_clock_outlined
                        : Icons.verified_user_outlined,
                    size: 64,
                    color: scheme.primary),
                const SizedBox(height: 16),
                Text(widget.expired ? 'انتهت صلاحية التفعيل' : 'تفعيل التطبيق',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  widget.expired
                      ? 'انتهت مدّة الترخيص لهذا الجهاز. أرسل «رقم الجهاز» أدناه '
                          'للحصول على رمز تفعيل جديد.'
                      : 'هذه النسخة مرخّصة لجهاز واحد. أرسل «رقم الجهاز» أدناه '
                          'للحصول على رمز التفعيل.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text('رقم الجهاز',
                          style:
                              TextStyle(color: scheme.primary, fontSize: 12)),
                      const SizedBox(height: 6),
                      SelectableText(
                        _deviceId,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _deviceId));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ رقم الجهاز')));
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('نسخ رقم الجهاز'),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _codeCtrl,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    labelText: 'رمز التفعيل',
                    hintText: 'ألصق الرمز هنا',
                    errorText: _error ? 'رمز غير صحيح لهذا الجهاز' : null,
                    prefixIcon: const Icon(Icons.vpn_key),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _activate,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.lock_open),
                    label: const Text('تفعيل'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## 6) الربط في `main.dart`

```dart
import 'package:flutter/material.dart';
import 'security/activation_gate.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const ActivationGate(child: HomeScreen()), // شاشتك الرئيسية
    );
  }
}
```

عرض الأيام المتبقّية (اختياري):
```dart
final i = await LicenseService.instance.info();
if (i.state == LicenseState.active && !i.permanent) {
  print('المتبقّي: ${i.daysLeft} يوم — ينتهي ${i.expiry}');
}
```

---

## 7) متجهات اختبار (للتأكّد من تطابق التنفيذ)

بادئة `UNIV1`، المفتاح العالميّ، الناتج بلا شرطات (106 حرفًا):

| رقم الجهاز | المدّة | الكود |
|---|---|---|
| `TESTDEVICE234567` | 0 (دائم) | `AAANSJ2UELQ398JB5X4FPSV9DWUW3XSRP367RBVF9ASD7URBN55UTUBRMHWNYEQTL6HQLVS43XA5B3K7QK2ZU7FF4GX8PJB93BE4CKB2AJ` |
| `TESTDEVICE234567` | 30 | `AARLNZUCVGUA827D3FUBNPHB9ESX6KZX4EWUEM7NX7LU2CJ5XX4JPZSBUPAWUDNKH2TAP2P7992LQ99UNV9HP55BME68X8EM8FBU69UBAJ` |

---

## 8) نسخة الويب/JavaScript (تحقّق + إدارة المدّة)

```bash
npm i tweetnacl
```
```js
import nacl from 'tweetnacl';

const B32 = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const PREFIX = 'UNIV1';
const PUBKEY_B64 = '0JXPjbbPjczfYbYxl+jy1vOVcsEJT+CPbUIQgXNCStU=';
const DAY_MS = 86400000;

const enc = (s) => new TextEncoder().encode(s);
const normalize = (s) => s.toUpperCase().replace(/[^A-Z0-9]/g, '');
function b64ToBytes(b){const x=atob(b),o=new Uint8Array(x.length);for(let i=0;i<x.length;i++)o[i]=x.charCodeAt(i);return o;}
function base32Decode(str){let bits=0,value=0;const out=[];for(const c of str){const i=B32.indexOf(c);if(i<0)continue;value=(value<<5)|i;bits+=5;if(bits>=8){out.push((value>>>(bits-8))&255);bits-=8;}value&=(1<<bits)-1;}return Uint8Array.from(out);}

// معرّف جهاز للويب: عشوائيّ مخزَّن، ثم نفس اشتقاق التطبيق (يلزم SHA-256 — استخدم WebCrypto).
async function webDeviceId() {
  let raw = localStorage.getItem('lic_raw');
  if (!raw) { const b=crypto.getRandomValues(new Uint8Array(16)); raw=btoa(String.fromCharCode(...b)); localStorage.setItem('lic_raw',raw); }
  const data = enc('alaoufi:' + raw);
  const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', data));
  // base32 لأوّل 10 بايت:
  let bits=0,value=0,id='';
  for (const x of hash.slice(0,10)) { value=(value<<8)|x; bits+=8; while(bits>=5){id+=B32[(value>>>(bits-5))&31];bits-=5;} value&=(1<<bits)-1; }
  if (bits>0) id+=B32[(value<<(5-bits))&31];
  return id;
}

function verifyCode(code, deviceId) {
  const pkt = base32Decode(normalize(code));
  if (pkt.length !== 66) return null;
  const dur = (pkt[0] << 8) | pkt[1];
  const sig = pkt.slice(2);
  const msg = enc(`${PREFIX}|${normalize(deviceId)}|${dur}`);
  return nacl.sign.detached.verify(msg, sig, b64ToBytes(PUBKEY_B64)) ? dur : null;
}
function activate(dur){const n=Date.now();localStorage.setItem('lic_record',JSON.stringify({d:dur,a:n,s:n}));}
function licenseState() {
  const raw = localStorage.getItem('lic_record'); if (!raw) return {state:'none'};
  const r = JSON.parse(raw); const now = Date.now(); const eff = Math.max(now, r.s ?? r.a);
  if (eff > (r.s ?? r.a)) { r.s = eff; localStorage.setItem('lic_record', JSON.stringify(r)); }
  if (r.d === 0) return {state:'active', permanent:true};
  const exp = r.a + r.d*DAY_MS;
  return eff < exp ? {state:'active', daysLeft:Math.ceil((exp-eff)/DAY_MS), expiry:exp} : {state:'expired', expiry:exp};
}
```

---

## 9) أمان (مهمّ)

- **لا يُوضع المفتاح الخاصّ في أيّ تطبيق ولا كود ويب.** المطوّر يحتاج العامّ فقط.
- المفتاح العامّ نشرُه آمن (لا يولّد أكواد).
- الحماية تعمل دون إنترنت. مسح بيانات التطبيق يعيده «غير مفعّل» لكن رقم الجهاز
  ثابت فيُعاد إدخال نفس الرمز ما دامت المدّة سارية.
- رقم الجهاز ثابت عبر التحديث/إعادة التثبيت (نفس مفتاح التوقيع)، ويتغيّر بضبط
  المصنع أو اختلاف مفتاح التوقيع.
```
