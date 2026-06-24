# مواصفة آلية التفعيل والمفاتيح (KEYGEN_SPEC)

توثيق دقيق ومكتمل لآلية الترخيص/التفعيل المستخدمة في تطبيق **مذكراتي (Alaoufi
Notes)**، بغرض إعادة استخدامها في تطبيقات أخرى (ويب/JavaScript) وفي مولّد مفاتيح
(keygen) موحّد. كُتب هذا الملف من قراءة الكود الفعليّ، لا من الذاكرة.

> **الخلاصة في سطر:** المفتاح = **توقيع Ed25519** (تعمية غير متماثلة) على النصّ
> `MDKL1|<معرّف الجهاز>|<المدّة بالأيام>`، يُرزَم مع بايتي المدّة ويُرمَّز Base32
> مخصّص. التطبيق يتحقّق بالمفتاح **العامّ** المدمج فقط. لا HMAC ولا سرّ متماثل.

المصادر في المستودع:
- `mudhakkarati/lib/services/license_service.dart` — جهة **التحقّق** (داخل التطبيق).
- `keygen/_src/lib/license_codec.dart` — جهة **التوليد** (تطبيق المولّد المستقلّ).
- `keygen/_src/lib/main.dart` — واجهة المولّد ومصدر البذرة (Seed).
- `mudhakkarati/lib/features/security/activation_gate.dart` — بوابة التفعيل (واجهة).
- `mudhakkarati/test/license_test.dart` — اختبارات التطابق (متجهات مرجعية).
- `mudhakkarati/tool/license.dart` — **أداة CLI قديمة وغير متوافقة** (انظر التحذير).

---

## 0) ملخّص بارز للمصمّم (TL;DR)

| العنصر | القيمة |
|---|---|
| نوع التعمية | **Ed25519** (توقيع رقمي غير متماثل، RFC 8032) |
| السرّ | **بذرة 32 بايت** (المفتاح الخاصّ) — بحوزة المالك فقط، **ليست في المستودع** |
| المدمج في التطبيق | المفتاح **العامّ** فقط (Base64، 32 بايت) — للتحقّق لا للتوليد |
| النصّ المُوقَّع | `MDKL1\|<deviceId>\|<duration>` (UTF‑8) |
| بادئة الصيغة | `MDKL1` (حرفيًّا — جزء من النصّ المُوقَّع) |
| الحقول المدمجة | المدّة بالأيام (0 = دائم)، مربوط بمعرّف الجهاز |
| رزمة البايتات | `[durHi, durLo, ...64‑byte signature]` = **66 بايت** |
| الترميز | **Base32 مخصّص** أبجدية `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` |
| التجميع | مجموعات من **5** بفواصل `-` (تجميل فقط، يُزال عند الإدخال) |
| طول المفتاح | 66 بايت → **106 حرف Base32** (+ شرطات) |
| لا يوجد | checksum منفصل (التوقيع نفسه هو التحقّق)، ولا فترة تجريبية |

المفتاح العامّ المدمج فعليًّا في هذا التطبيق:
```
Wu3tven4KhEEuNqUNLatFTLljCgjFnJXtFc3QHYlhk8=
```
(هذا عامّ — نشرُه آمن. لا يمكن توليد مفاتيح منه.)

---

## 1) معرّف الجهاز (Device ID)

يُحسب **داخل التطبيق على الجهاز**، ويُعرَض للمستخدم كي يرسله للمالك. المولّد لا
يحسبه — بل يأخذه **نصًّا جاهزًا** ويوقّع عليه. (المرجع: `license_service.dart:74‑112`.)

### المصدر الخام (`_hardwareFingerprint`)
1. **Android:** حزمة `android_id: ^0.5.1` → `AndroidId().getId()` التي تعيد
   `Settings.Secure.ANDROID_ID` (٦٤‑بت، 16 خانة hex).
2. **iOS:** حزمة `device_info_plus` → `iosInfo.identifierForVendor`.
3. **غير ذلك أو عند الفشل:** 16 بايت عشوائية (`Random.secure`) مُرمَّزة Base64
   (احتياط فقط — غير ثابت).

### الاشتقاق
```
raw    = ANDROID_ID (أو identifierForVendor أو عشوائي)
digest = SHA‑256( UTF8("mudhakkarati:" + raw) )
id     = base32_custom( digest[0 .. 10) )          // أوّل 10 بايت = 16 حرف Base32
```
- `"mudhakkarati:"` بادئة **خاصّة بالتطبيق** (ليست سرًّا) — تمنع تطابق المعرّف بين
  تطبيقاتك لو استُخدم نفس المصدر الخام. غيّرها لكل تطبيق إن أردت معرّفات مستقلّة.
- 10 بايت = 80 بت ÷ 5 = **16 حرف Base32** بالضبط.
- يُخزَّن مؤقتًا في `flutter_secure_storage` تحت المفتاح `lic_device_id`.

### العرض المُجمّل (`deviceIdPretty`)
مجموعات من **4** بفواصل `-`: `XXXX-XXXX-XXXX-XXXX` (تجميل فقط).

### الثبات (مهمّ)
- **عبر تحديثات التطبيق:** ثابت (مخزَّن + مصدره ANDROID_ID ثابت).
- **بعد إعادة التثبيت:** على أندرويد منذ 8.0، `ANDROID_ID` ثابت لكلّ
  (مفتاح توقيع التطبيق × المستخدم × الجهاز) ⇒ يبقى **نفسه** بعد إلغاء التثبيت
  وإعادته (ما دام مفتاح التوقيع نفسه). لذا المعرّف يعود كما كان.
- **بعد ضبط المصنع:** يتغيّر `ANDROID_ID` ⇒ معرّف **مختلف** ⇒ يلزم رمز جديد.
- **عند تغيير مفتاح توقيع الـAPK:** يتغيّر `ANDROID_ID` ⇒ معرّف مختلف.

### بديل الويب (لا يوجد ANDROID_ID)
المتصفّح لا يوفّر معرّف عتاد ثابت. خيارات مكافئة:
1. **(موصى به) معرّف مثبَّت محليًّا:** ولّد 16 بايت عشوائية مرّة واحدة، خزّنها في
   `localStorage`، ثم مرّرها بنفس خطّ الأنابيب
   (`base32(sha256("app:"+raw)[0:10])`) ⇒ معرّف ثابت لهذا المتصفّح. يتغيّر عند
   مسح بيانات الموقع أو متصفّح آخر (يشبه «إعادة التثبيت»).
2. **بصمة متصفّح** (مثل FingerprintJS) لو احتجت ثباتًا أعلى عبر مسح التخزين —
   مقابل دقّة/خصوصية أقلّ.
3. لمزامنة حقيقية عبر الأجهزة: اربط المعرّف بحساب مستخدم (بريد) بدل العتاد.

> المولّد محايد تمامًا تجاه مصدر المعرّف: يوقّع أيّ نصّ تعطيه إيّاه. فاختيار مصدر
> المعرّف قرار **كلّ تطبيق** على حدة.

---

## 2) رمز التفعيل — التوليد (جهة المالك)

المرجع: `license_codec.dart:18‑30`. الخطوات بالترتيب الحرفيّ:

```
1. id   = upper(deviceId) مع حذف كلّ ما ليس [A-Z0-9]   // إزالة الشرطات/المسافات
2. dur  = clamp(durationDays, 0, 65535)                // 0 = دائم
3. kp   = Ed25519.keyPairFromSeed(seed)                // seed = 32 بايت (سرّ المالك)
4. msg  = UTF8( "MDKL1" + "|" + id + "|" + dur )       // dur كنصّ عشري
5. sig  = Ed25519.sign(msg, kp)                        // 64 بايت
6. bytes = [ (dur >> 8) & 0xFF, dur & 0xFF ] ++ sig    // 2 + 64 = 66 بايت
7. code = group5( base32_custom(bytes) )               // 106 حرف + شرطات كلّ 5
```

- المدّة تظهر **مرّتين**: كنصّ عشري داخل الرسالة المُوقَّعة، وكبايتين في مقدّمة
  الرزمة (كي يقرأها التطبيق **قبل** التحقّق ليبني نفس الرسالة).
- لا توجد خانة checksum: أيّ تلاعب يُفسد التوقيع فيفشل التحقّق.

---

## 3) رمز التفعيل — التحقّق (داخل التطبيق)

المرجع: `license_service.dart:157‑177` (`tryActivate`).

```
1. norm  = upper(code) مع حذف كلّ ما ليس [A-Z0-9]
2. bytes = base32_decode_custom(norm)
3. إذا length(bytes) != 66  ⇒ فشل
4. dur   = (bytes[0] << 8) | bytes[1]
5. sig   = bytes[2 .. 66)                              // 64 بايت
6. id    = deviceId()                                  // يُعاد حسابه محليًّا
7. msg   = UTF8( "MDKL1" + "|" + id + "|" + dur )
8. ok    = Ed25519.verify(msg, sig, EMBEDDED_PUBLIC_KEY)
9. إذا ok ⇒ فعّل بالمدّة dur ؛ وإلا ⇒ فشل
```

- الربط بالجهاز: التطبيق يستخدم معرّفه المحليّ في الرسالة، فرمز جهاز آخر لا يتحقّق.
- منع التزوير: لا يمكن توليد توقيع صحيح دون المفتاح الخاصّ.

---

## 4) تخزين التفعيل وحالاته

### السجلّ (`_activate` / `_writeRecord`، `license_service.dart:200‑258`)
عند النجاح يُكتب JSON:
```json
{ "d": <duration_days>, "a": <activatedEpochMs>, "s": <lastSeenEpochMs> }
```
- `d` = المدّة بالأيام (0 = دائم).
- `a` = لحظة التفعيل (ms منذ 1970).
- `s` = آخر وقت رأيناه (حارس الساعة).

يُخزَّن في موضعين للمتانة:
- `flutter_secure_storage` المفتاح `lic_record` (مشفّر).
- ملف دائم `.mdk_license` في `getApplicationSupportDirectory()` (ينجو من فشل
  قراءة التخزين الآمن المؤقّت؛ يُعاد مزامنته تلقائيًّا).

### الحالات (`LicenseState`)
- `disabled`: المفتاح العامّ غير مضبوط (فارغ أو يبدأ بـ`REPLACE_`) ⇒ التطبيق
  **مفتوح بلا ترخيص** (وضع تطوير).
- `none`: لا سجلّ ⇒ تظهر شاشة التفعيل.
- `active`: مفعّل وسارٍ (دائم أو ضمن المدّة).
- `expired`: انتهت المدّة.

### حساب الانتهاء وحارس الساعة (`info`، `license_service.dart:123‑152`)
```
now    = الآن (ms)
effNow = max(now, lastSeen)          // لا يُسمح بإرجاع الساعة للوراء
إن تغيّر effNow ⇒ احفظ s = effNow
إن d == 0            ⇒ active دائم
expiry = a + d * 86400000
إن effNow <  expiry  ⇒ active، daysLeft = ceil((expiry - effNow)/86400000)
إن effNow >= expiry  ⇒ expired
```
- **لا فترة تجريبية**: بلا تفعيل ⇒ مقفل مباشرة (إلا في وضع `disabled`).

### استرجاع المالك (`recoverWithOwnerSeed`، `license_service.dart:182‑198`)
إدخال البذرة (64 خانة hex) ⇒ يشتقّ المفتاح العامّ ⇒ يقارنه بالمدمج **بمقارنة
ثابتة الزمن** ⇒ إن طابق يفعّل **دائمًا** (d=0). ضمانة ألّا يُحبَس المالك عن بياناته.

---

## 5) الترميز Base32 المخصّص

المرجع: `license_service.dart:277‑312` و`license_codec.dart:64‑80` (متطابقان).

- الأبجدية (Crockford‑ish، بلا حروف ملتبسة I L O U):
  ```
  ABCDEFGHJKLMNPQRSTUVWXYZ23456789      // 32 رمزًا، الفهرس 0..31
  ```
- **الترميز:** اقرأ البايتات MSB‑أولًا، كدّس البتات، أخرج 5 بتات لكلّ رمز؛ البتات
  المتبقّية في النهاية تُزاح يسارًا وتُكمَّل بأصفار.
- **الفكّ:** عكسه؛ يتجاهل أيّ رمز خارج الأبجدية (فالشرطات/المسافات/الأحرف الصغيرة
  بعد التطبيع لا تضرّ). البتّات الزائدة في النهاية تُهمَل.
- ليس Base32 القياسيّ (RFC 4648) — أبجدية مختلفة وبلا حشو `=`.

---

## 6) السرّ وأين هو

- **المدمج في التطبيق:** المفتاح العامّ فقط
  (`_publicKeyB64 = "Wu3tven4KhEEuNqUNLatFTLljCgjFnJXtFc3QHYlhk8="`). عامّ، للتحقّق.
- **السرّ الحقيقيّ:** البذرة (Seed) 32 بايت = المفتاح الخاصّ Ed25519. **ليست في
  المستودع إطلاقًا.** تُخزَّن في التخزين الآمن لتطبيق المولّد تحت المفتاح
  `owner_seed_hex` (يُدخلها المالك مرّة)، أو تُمرَّر لأداة CLI.
- لإعادة إنتاج **نفس** المفاتيح السابقة في أيّ لغة: يلزمك **نفس البذرة** التي
  تطابق المفتاح العامّ أعلاه. بدونها لا يمكن إنتاج مفاتيح صالحة (هذا هو المقصود).

> ⚠️ لا تضع البذرة في كود الويب المنشور للعميل أبدًا — أيّ JS يصل للمتصفّح مكشوف.
> ضع التوليد في أداة مالك محليّة أو خادم خاصّ، لا في صفحة عميل.

---

## 7) للمولّد الموحّد لعدّة تطبيقات

كلّ تطبيق يجب أن يختلف في:
1. **زوج المفاتيح** (بذرة/عامّ خاصّ به) — لئلا يفتح رمزُ تطبيقٍ تطبيقًا آخر.
2. **بادئة الصيغة** `msgPrefix` (هنا `MDKL1`) — يجب أن تطابق ثابت `_msgPrefix`
   في كلّ تطبيق. اجعلها مميِّزة لكلّ تطبيق (مثل `APP2L1`).
3. (اختياري) بادئة اشتقاق معرّف الجهاز (`"mudhakkarati:"`).

ابقِ ثابتًا (لتظلّ المفاتيح متوافقة عبر تطبيقاتك): خوارزمية Ed25519، رزمة
`[durHi,durLo,sig]`، أبجدية Base32، والتجميع. فالمولّد الموحّد = نفس الدالة مع
(prefix, seed, publicKey) لكلّ تطبيق.

---

## 8) ⚠️ تحذير: `mudhakkarati/tool/license.dart` قديم وغير متوافق

أداة CLI `sign` فيه توقّع `UTF8(deviceId)` فقط (بلا بادئة `MDKL1`، بلا مدّة)
وتُخرِج التوقيع **Base64**. هذا **لا يطابق** التحقّق الحالي (الذي يتوقّع
`MDKL1|id|dur` و66 بايت Base32). الصيغة المعتمدة الوحيدة هي
`LicenseCodec` ↔ `LicenseService`. تجاهل `tool/license.dart` أو حدّثه.

---

## 9) التطبيق المرجعيّ — Dart (صافٍ، بلا اعتماد على Flutter)

```dart
import 'dart:convert';
import 'package:cryptography/cryptography.dart'; // ^2.x

const _b32 = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String base32Encode(List<int> bytes) {
  var bits = 0, value = 0;
  final out = StringBuffer();
  for (final b in bytes) {
    value = (value << 8) | b; bits += 8;
    while (bits >= 5) { out.write(_b32[(value >> (bits - 5)) & 31]); bits -= 5; }
    value &= (1 << bits) - 1;
  }
  if (bits > 0) out.write(_b32[(value << (5 - bits)) & 31]);
  return out.toString();
}

List<int> base32Decode(String s) {
  var bits = 0, value = 0;
  final out = <int>[];
  for (final ch in s.split('')) {
    final idx = _b32.indexOf(ch);
    if (idx < 0) continue;
    value = (value << 5) | idx; bits += 5;
    if (bits >= 8) { out.add((value >> (bits - 8)) & 0xff); bits -= 8; }
    value &= (1 << bits) - 1;
  }
  return out;
}

String _norm(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
String _group5(String s) {
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && i % 5 == 0) out.write('-');
    out.write(s[i]);
  }
  return out.toString();
}

/// توليد رمز (يحتاج البذرة 32 بايت).
Future<String> generateKey({
  required String deviceId,
  required int durationDays,
  required List<int> seed,
  String prefix = 'MDKL1',
}) async {
  final ed = Ed25519();
  final id = _norm(deviceId);
  final dur = durationDays.clamp(0, 65535);
  final kp = await ed.newKeyPairFromSeed(seed);
  final msg = utf8.encode('$prefix|$id|$dur');
  final sig = await ed.sign(msg, keyPair: kp);
  final bytes = <int>[(dur >> 8) & 0xff, dur & 0xff, ...sig.bytes];
  return _group5(base32Encode(bytes));
}

/// تحقّق (يحتاج المفتاح العامّ فقط).
Future<bool> verifyKey({
  required String code,
  required String deviceId,
  required String publicKeyB64,
  String prefix = 'MDKL1',
}) async {
  final ed = Ed25519();
  final bytes = base32Decode(_norm(code));
  if (bytes.length != 66) return false;
  final dur = (bytes[0] << 8) | bytes[1];
  final sig = bytes.sublist(2);
  final msg = utf8.encode('$prefix|${_norm(deviceId)}|$dur');
  final pub = SimplePublicKey(base64Decode(publicKeyB64),
      type: KeyPairType.ed25519);
  return ed.verify(msg, signature: Signature(sig, publicKey: pub));
}
```

---

## 10) شِبه‑كود محايد للّغة (Pseudocode)

```
CONST B32_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
CONST PREFIX       = "MDKL1"            // per-app

FUNCTION normalize(s):
    RETURN uppercase(s) with all chars NOT in [A-Z0-9] removed

FUNCTION base32_encode(bytes):
    bits = 0; value = 0; out = ""
    FOR b IN bytes:
        value = (value << 8) OR b ; bits += 8
        WHILE bits >= 5:
            out += B32_ALPHABET[(value >> (bits-5)) AND 31] ; bits -= 5
        value = value AND ((1 << bits) - 1)
    IF bits > 0:
        out += B32_ALPHABET[(value << (5-bits)) AND 31]
    RETURN out

FUNCTION base32_decode(str):
    bits = 0; value = 0; out = []
    FOR ch IN str:
        idx = indexOf(B32_ALPHABET, ch)
        IF idx < 0: CONTINUE
        value = (value << 5) OR idx ; bits += 5
        IF bits >= 8:
            out.append((value >> (bits-8)) AND 0xFF) ; bits -= 8
        value = value AND ((1 << bits) - 1)
    RETURN out

FUNCTION generate(deviceId, durationDays, seed32):
    id   = normalize(deviceId)
    dur  = clamp(durationDays, 0, 65535)
    msg  = utf8(PREFIX + "|" + id + "|" + decimal(dur))
    sig  = Ed25519_sign(msg, seed32)               // 64 bytes, deterministic
    pkt  = [ (dur >> 8) AND 0xFF, dur AND 0xFF ] ++ sig   // 66 bytes
    RETURN group_every_5_with_dashes(base32_encode(pkt))

FUNCTION verify(code, deviceId, publicKey32):
    pkt = base32_decode(normalize(code))
    IF length(pkt) != 66: RETURN false
    dur = (pkt[0] << 8) OR pkt[1]
    sig = pkt[2 .. 66)
    msg = utf8(PREFIX + "|" + normalize(deviceId) + "|" + decimal(dur))
    RETURN Ed25519_verify(msg, sig, publicKey32)
```

---

## 11) نسخة JavaScript مكافئة (نفس المخرجات بالضبط)

Ed25519 حتميّ (RFC 8032)، فنفس البذرة + نفس الرسالة ⇒ **نفس التوقيع** ⇒ نفس
المفتاح حرفيًّا في Dart وJS. أبسط مكتبة: **tweetnacl** (تتضمّن كلّ شيء).

```bash
npm i tweetnacl
```

```js
import nacl from 'tweetnacl';

const B32 = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const PREFIX = 'MDKL1';                 // غيّرها لكلّ تطبيق

const enc = (s) => new TextEncoder().encode(s);
const normalize = (s) => s.toUpperCase().replace(/[^A-Z0-9]/g, '');

function hexToBytes(hex) {
  const h = hex.trim().toLowerCase().replace(/[^0-9a-f]/g, '');
  const out = new Uint8Array(h.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(h.substr(i * 2, 2), 16);
  return out;
}
function b64ToBytes(b64) {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function base32Encode(bytes) {
  let bits = 0, value = 0, out = '';
  for (const b of bytes) {
    value = (value << 8) | b; bits += 8;
    while (bits >= 5) { out += B32[(value >>> (bits - 5)) & 31]; bits -= 5; }
    value &= (1 << bits) - 1;
  }
  if (bits > 0) out += B32[(value << (5 - bits)) & 31];
  return out;
}
function base32Decode(str) {
  let bits = 0, value = 0; const out = [];
  for (const ch of str) {
    const idx = B32.indexOf(ch);
    if (idx < 0) continue;
    value = (value << 5) | idx; bits += 5;
    if (bits >= 8) { out.push((value >>> (bits - 8)) & 0xff); bits -= 8; }
    value &= (1 << bits) - 1;
  }
  return Uint8Array.from(out);
}
const group5 = (s) => s.replace(/(.{5})/g, '$1-').replace(/-$/, '');

/// توليد (يحتاج البذرة 32 بايت hex) — استخدمه في أداة مالك/خادم، لا في صفحة عميل.
function generateKey({ deviceId, durationDays, seedHex }) {
  const id = normalize(deviceId);
  let dur = durationDays | 0; dur = Math.max(0, Math.min(65535, dur));
  const seed = hexToBytes(seedHex);              // 32 بايت
  const kp = nacl.sign.keyPair.fromSeed(seed);   // secretKey = 64 بايت
  const msg = enc(`${PREFIX}|${id}|${dur}`);
  const sig = nacl.sign.detached(msg, kp.secretKey); // 64 بايت
  const pkt = new Uint8Array(66);
  pkt[0] = (dur >> 8) & 0xff; pkt[1] = dur & 0xff; pkt.set(sig, 2);
  return group5(base32Encode(pkt));
}

/// تحقّق (يحتاج المفتاح العامّ Base64 فقط) — صالح للعميل.
function verifyKey({ code, deviceId, publicKeyB64 }) {
  const pkt = base32Decode(normalize(code));
  if (pkt.length !== 66) return false;
  const dur = (pkt[0] << 8) | pkt[1];
  const sig = pkt.slice(2);
  const msg = enc(`${PREFIX}|${normalize(deviceId)}|${dur}`);
  return nacl.sign.detached.verify(msg, sig, b64ToBytes(publicKeyB64));
}

// مثال:
// const key = generateKey({ deviceId: 'ABCD-2345-EFGH-6789', durationDays: 30, seedHex: '<64 hex>' });
// verifyKey({ code: key, deviceId: 'ABCD2345EFGH6789',
//             publicKeyB64: 'Wu3tven4KhEEuNqUNLatFTLljCgjFnJXtFc3QHYlhk8=' });
```

### بديل بمكتبة @noble/ed25519 (v2)
```js
import * as ed from '@noble/ed25519';
import { sha512 } from '@noble/hashes/sha512';
ed.etc.sha512Sync = (...m) => sha512(ed.etc.concatBytes(...m)); // مطلوب للوضع المتزامن
// sig = ed.sign(msg, seed32)              // seed = 32 بايت (private)
// ok  = ed.verify(sig, msg, publicKey32)
```
المخرجات مطابقة لـ tweetnacl ولـ Dart `cryptography` (كلّها RFC 8032).

---

## 12) متجهات اختبار للتأكّد من التطابق

من `mudhakkarati/test/license_test.dart`:
- رزمة مفكوكة لمفتاح صحيح **طولها 66 بايت** بالضبط (`مدّة 2 + توقيع 64`).
- المدّة تُقرأ كـ `(b[0]<<8)|b[1]`؛ القيمة 0 = دائم.
- تغيير الجهاز أو المدّة أو أيّ بايت في التوقيع ⇒ يفشل التحقّق.

**للتحقّق العمليّ من تطابق Dart↔JS:** ولّد مفتاحًا لنفس
`(seed, deviceId="ABCD2345EFGH6789", duration=30)` في الجهتين وقارن الناتج حرفيًّا
— يجب أن يكونا **متطابقين تمامًا** (Ed25519 حتميّ). إن اختلفا فالغالب اختلاف في
البادئة أو التطبيع أو أبجدية Base32.

---

## 13) قائمة مراجعة لإعادة الاستخدام في تطبيق ويب

- [ ] اختر مصدر معرّف جهاز للويب (القسم 1: معرّف مثبَّت في `localStorage`).
- [ ] طبّق `base32` و`normalize` و`generate/verify` (القسم 11) — انسخها كما هي.
- [ ] ضع **التوليد** (بالبذرة) في أداة مالك محليّة/خادم، لا في صفحة العميل.
- [ ] ضمّن **المفتاح العامّ** فقط في الويب للتحقّق.
- [ ] للمولّد الموحّد: مرّر `(prefix, seed, publicKey)` المناسبة لكلّ تطبيق.
- [ ] للحفاظ على صلاحية المفاتيح القديمة: استخدم **نفس البذرة + نفس `MDKL1`**.
```
