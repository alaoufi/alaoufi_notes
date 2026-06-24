# تسليم المطوّر — حماية وتفعيل تطبيق «مراح» (Marah)

ملفّ واحد شامل لبناء حماية التفعيل (المربوطة بالجهاز، مع مدّة صلاحية) في تطبيق
«مراح». الآلية مطابقة لتطبيق «مذكراتي» المعتمد، وتعمل **دون إنترنت بالكامل**.

> **للمطوّر:** أنت تبني **جهة التحقّق** فقط. تحتاج **المفتاح العامّ** أدناه (غير
> سرّي). **لا تحتاج — ولن تُعطى — المفتاح الخاصّ (Seed)؛** فهو يبقى لدى المالك في
> أداة توليد الأكواد. بدونه لا يستطيع أحد تزوير أكواد، وهذا هو المقصود.

---

## 0) الفكرة باختصار

- لكلّ جهاز **رقم جهاز** ثابت يُعرض للمستخدم.
- المالك يولّد **رمز تفعيل** لذلك الجهاز بمدّة محدّدة (أيام أو دائم) عبر أداة
  المولّد (لدى المالك).
- التطبيق يتحقّق من الرمز بالمفتاح **العامّ** المدمج، فيُفعّل لجهاز واحد فقط.
- الرمز لا ينتقل لجهاز آخر، ونشر الـAPK بلا فائدة (كلّ جهاز يحتاج رمزه).
- **المدّة مدمجة في الرمز وموقّعة** ⇒ لا يمكن تغييرها، ويُقفل التطبيق عند انتهائها.

نوع التعمية: **Ed25519** (توقيع غير متماثل، RFC 8032). لا HMAC ولا سرّ متماثل.

---

## 1) معلومات «مراح» (ثوابت هذا التطبيق)

| العنصر | القيمة |
|---|---|
| بادئة الصيغة `prefix` | `MRHL1` |
| المفتاح العامّ (Base64) | `q6t0BfdSs/AF9EAHkRAwAoaqRwHFp7m052uCRxlwKw4=` |
| بادئة اشتقاق معرّف الجهاز | `marah:` |
| صيغة الرمز | 66 بايت (مدّة 2 + توقيع 64) → 106 حرف Base32 مخصّص |

> هذه القيم تخصّ «مراح» وحده. لا تستخدم قيم تطبيق آخر.

---

## 2) آلية المدّة (الأهمّ)

المدّة محفوظة بعد التفعيل في سجلّ، وتُفحَص عند كلّ فتح:

```
السجلّ المخزَّن بعد التفعيل:
  d = المدّة بالأيام (0 = دائم)
  a = لحظة التفعيل (ms منذ 1970)
  s = آخر وقت رآه التطبيق   ← حارس ضدّ إرجاع الساعة

عند كلّ فتح/استئناف للتطبيق:
  expiry  = a + d * 86400000                 // يوم = 86,400,000 ms
  effNow  = max(now, s)                       // يمنع تمديد المدّة بإرجاع الساعة
  if (effNow > s) خزّن s = effNow
  if d == 0            ⇒ دائم (لا ينتهي)
  if effNow <  expiry  ⇒ مفعّل، المتبقّي = ceil((expiry - effNow)/86400000)
  if effNow >= expiry  ⇒ منتهٍ ⇒ اقفل واطلب رمزًا جديدًا
```

نقاط مهمّة:
- **حارس الساعة:** يُخزَّن «أعلى وقت رُئي»؛ فإرجاع تاريخ الجهاز للوراء لا يُمدّد المدّة.
- **لا فترة تجريبية:** بلا تفعيل ⇒ مقفل (إلا في وضع التطوير حين لا يُضبط مفتاح عامّ).
- **تخزين مزدوج:** السجلّ في التخزين الآمن + ملفّ دائم، لتحمّل فشل القراءة المؤقّت.
- حدّ المدّة: 0..65535 يومًا (≈ 179 سنة)، و0 = دائم.

> ملاحظة: مسح بيانات التطبيق يُصفّر السجلّ (يعود «غير مفعّل»)، لكنّ رقم الجهاز
> نفسه ثابت، فيُعاد إدخال الرمز نفسه (لا يلزم رمز جديد) ما دامت المدّة سارية.

---

## 3) خطوات الدمج (Flutter)

1. أضف الحزم في `pubspec.yaml`:
   ```yaml
   dependencies:
     cryptography: ^2.9.0
     crypto: ^3.0.3
     android_id: ^0.5.1
     device_info_plus: ^12.4.0
     flutter_secure_storage: ^9.0.0
     path_provider: ^2.1.0
   ```
2. أنشئ `lib/services/license_service.dart` بمحتوى القسم (4).
3. أنشئ `lib/security/activation_gate.dart` بمحتوى القسم (5).
4. لُفّ الشاشة الرئيسية بالبوابة في `main.dart` (القسم 6).
5. لأندرويد: `minSdkVersion 26+` (مطلوب لـ flutter_secure_storage الحديث).

---

## 4) ملفّ `lib/services/license_service.dart` (كامل، جاهز لمراح)

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

  // مفتاح مراح العامّ (تحقّق فقط — غير سرّي).
  static const String _publicKeyB64 =
      'q6t0BfdSs/AF9EAHkRAwAoaqRwHFp7m052uCRxlwKw4=';

  // بادئة مراح — يجب أن تطابق المولّد حرفيًّا.
  static const String _msgPrefix = 'MRHL1';

  static const _kDeviceId = 'lic_device_id';
  static const _kRecord = 'lic_record';
  static const _licenseFile = '.marah_license';
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
    final digest = crypto.sha256.convert(utf8.encode('marah:$raw'));
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

---

## 5) ملفّ `lib/security/activation_gate.dart` (كامل)

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/license_service.dart';

/// بوابة التفعيل: تظهر قبل المحتوى إن لم يُفعّل أو انتهت مدّته، وتُعيد الفحص عند
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
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('© مراح',
                      style: TextStyle(color: scheme.outline, fontSize: 12)),
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

void main() => runApp(const MarahApp());

class MarahApp extends StatelessWidget {
  const MarahApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مراح',
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      // الشاشة الرئيسية محميّة بالبوابة:
      home: const ActivationGate(child: HomeScreen()),
    );
  }
}
```

لعرض الأيام المتبقّية داخل التطبيق (اختياري):
```dart
final info = await LicenseService.instance.info();
if (!info.permanent && info.state == LicenseState.active) {
  print('المتبقّي: ${info.daysLeft} يوم — ينتهي ${info.expiry}');
}
```

---

## 7) كيف يولّد المالك رمزًا (لا يخصّ المطوّر)

عبر «مولّد الأكواد» (أداة المالك): يختار **مراح**، يلصق رقم الجهاز، يحدّد المدّة
(أيام أو دائم)، فيخرج الرمز ويرسله للمستخدم. المطوّر لا يحتاج هذه الأداة ولا البذرة.

---

## 8) إن كان «مراح» ويب/JavaScript (لا Flutter)

الآلية نفسها؛ يتغيّر فقط:
- **معرّف الجهاز:** لا يوجد معرّف عتاد. ولّد 16 بايت عشوائية مرّة، خزّنها في
  `localStorage`، ومرّرها بنفس الاشتقاق `base32(sha256("marah:"+raw)[0:10])`.
- **التخزين:** السجلّ (`{d,a,s}`) في `localStorage` بدل التخزين الآمن.
- **التحقّق:** Ed25519 عبر `tweetnacl` أو `@noble/ed25519`.

تحقّق + إدارة المدّة (JS):
```js
import nacl from 'tweetnacl';

const B32 = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const PREFIX = 'MRHL1';
const PUBKEY_B64 = 'q6t0BfdSs/AF9EAHkRAwAoaqRwHFp7m052uCRxlwKw4=';
const DAY_MS = 86400000;

const enc = (s) => new TextEncoder().encode(s);
const normalize = (s) => s.toUpperCase().replace(/[^A-Z0-9]/g, '');
function b64ToBytes(b64){const b=atob(b64),o=new Uint8Array(b.length);for(let i=0;i<b.length;i++)o[i]=b.charCodeAt(i);return o;}
function base32Decode(str){let bits=0,value=0;const out=[];for(const ch of str){const i=B32.indexOf(ch);if(i<0)continue;value=(value<<5)|i;bits+=5;if(bits>=8){out.push((value>>>(bits-8))&0xff);bits-=8;}value&=(1<<bits)-1;}return Uint8Array.from(out);}

// تحقّق من رمز ⇒ يعيد المدّة (>=0) أو null إن فشل.
function verifyCode(code, deviceId) {
  const pkt = base32Decode(normalize(code));
  if (pkt.length !== 66) return null;
  const dur = (pkt[0] << 8) | pkt[1];
  const sig = pkt.slice(2);
  const msg = enc(`${PREFIX}|${normalize(deviceId)}|${dur}`);
  const ok = nacl.sign.detached.verify(msg, sig, b64ToBytes(PUBKEY_B64));
  return ok ? dur : null;
}

// عند التفعيل: خزّن السجلّ.
function activate(dur) {
  const now = Date.now();
  localStorage.setItem('lic_record', JSON.stringify({ d: dur, a: now, s: now }));
}

// عند كلّ فتح: احسب الحالة (نفس منطق Flutter + حارس الساعة).
function licenseState() {
  const raw = localStorage.getItem('lic_record');
  if (!raw) return { state: 'none' };
  const rec = JSON.parse(raw);
  const now = Date.now();
  const effNow = Math.max(now, rec.s ?? rec.a);
  if (effNow > (rec.s ?? rec.a)) { rec.s = effNow; localStorage.setItem('lic_record', JSON.stringify(rec)); }
  if (rec.d === 0) return { state: 'active', permanent: true };
  const expiry = rec.a + rec.d * DAY_MS;
  if (effNow < expiry) return { state: 'active', permanent: false, daysLeft: Math.ceil((expiry - effNow) / DAY_MS), expiry };
  return { state: 'expired', expiry };
}
```

---

## 9) ملاحظات أمان

- **لا تضع المفتاح الخاصّ (Seed) في تطبيق مراح ولا في أيّ كود ويب يصل للعميل.**
  المطوّر يحتاج المفتاح **العامّ** فقط (موجود أعلاه). التوليد يبقى لدى المالك.
- المفتاح العامّ نشرُه داخل التطبيق آمن (لا يمكن توليد أكواد منه).
- الحماية تعمل دون إنترنت؛ مسح بيانات التطبيق يعيده «غير مفعّل» لكن رقم الجهاز
  ثابت فيُعاد إدخال الرمز نفسه. لمنعٍ أقوى لإعادة الضبط يلزم تحقّق عبر خادم.
- على أندرويد: رقم الجهاز ثابت عبر التحديث وإعادة التثبيت (نفس مفتاح توقيع الـAPK)،
  ويتغيّر بضبط المصنع أو تغيير مفتاح التوقيع.
```
