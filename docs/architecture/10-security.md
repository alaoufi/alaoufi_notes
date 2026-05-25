# 10 — الأمان

الأمان مُدمج في كل طبقة. هذه الوثيقة تجمع نموذج التهديد والضوابط والمسؤوليات.

## نموذج التهديد (STRIDE مختصر)

| التهديد | المخاطر الرئيسية | الضوابط |
|---|---|---|
| **Spoofing** | انتحال هوية لطلب خدمة، انتحال مزوّد | تحقّق متعدّد (نفاذ، OTP)، JWT موقَّع، device fingerprinting |
| **Tampering** | تعديل حالة طلب، تزوير تقييم، تعديل سعر | RLS صارم، state machine في trigger، توقيع webhook |
| **Repudiation** | إنكار رسالة، إنكار قبول طلب | `audit_log` غير قابل للحذف، الرسائل بـ timestamp خادم |
| **Information Disclosure** | تسرّب بيانات شخصية، تسرّب موقع | حاويات خاصة + signed URL، RLS كل جدول، tokenization للهواتف في التحليلات |
| **Denial of Service** | إغراق OTP، إغراق طلبات، إغراق دردشة | Cloudflare WAF، rate limits متعدّدة، حدّ معاملات/ساعة |
| **Elevation of Privilege** | مستخدم يحصل على صلاحيات إدارة | RLS مع `auth.uid()`، فحص ثلاثي للأدوار، فصل `service_role` |

## المصادقة

### طبقات

1. **Supabase Auth** يُصدر JWT بعد نجاح أحد التحققات.
2. **التحققات المخصّصة** تُغلَّف خلف Edge Functions:
   - `auth-send-otp` → يُرسل OTP عبر SMS/WhatsApp.
   - `auth-verify-otp` → عند النجاح يُنشئ/يُحدّث `auth.users` ويُصدر جلسة.
   - `auth-verify-nafath` → يبدأ تحقّق نفاذ ويستقبل callback.
   - `auth-verify-email` → ربط بريد للحساب.
3. **MFA اختياري** للأدمن (إجباري): TOTP عبر Supabase Auth MFA.

### الجلسات

- JWT صلاحيته 1 ساعة، refresh token 30 يوماً (متجدّد).
- كل refresh يُولّد token جديد ويُبطل القديم (rotation).
- المستخدم يستطيع رؤية الأجهزة النشطة وإنهاء جلسة (جدول `devices`).
- خروج إجباري لكل الجلسات عند تغيير كلمة المرور / تجميد الحساب.

### قواعد كلمة المرور

- 8+ أحرف، تنوّع (حرف كبير + رقم + رمز).
- haveibeenpwned check عبر k-anonymity API.
- bcrypt-based hashing (مُدار من Supabase Auth).
- ممنوع استخدام كلمات سرّ شائعة (قائمة سوداء top 10k).
- قفل بعد 5 محاولات فاشلة لمدة 15 دقيقة (IP + user).

### OTP

- 6 أرقام، صلاحية 5 دقائق، يُحرَق عند الاستخدام.
- 5 إرسالات/ساعة لكل رقم؛ تأخير تصاعدي 30s → 60s → 120s → 240s → 480s.
- 5 محاولات تحقّق/جلسة؛ ثم قفل 30 دقيقة.

## التفويض

تفاصيل كاملة في `05-roles-permissions.md`. ملخص:

- RLS مُفعَّل افتراضياً على كل جدول.
- `service_role` لا يُستخدم في كود العميل أبداً.
- كل server action تتحقّق من الدور قبل التنفيذ.
- `audit_log` يلتقط كل تغيير حسّاس.

## أمان البيانات

### البيانات الشخصية (PII)

| الحقل | الحساسية | الحماية |
|---|---|---|
| الاسم الكامل | متوسطة | RLS فقط |
| رقم الهاتف | عالية | RLS + tokenization في التحليلات + lock عند الذكر في السجلات |
| البريد | متوسطة | RLS |
| الموقع | عالية | يُكتب فقط أثناء طلب نشط؛ يُحذف بعد إكماله |
| رقم الهوية | عالية جداً | تشفير على مستوى تطبيق + قراءة فقط من Edge Function للإدارة |
| السجل التجاري | متوسطة | RLS + bucket خاص |
| كلمة المرور | حرجة | hash (لا تُخزَّن plain أبداً) |

### التشفير

- في النقل: HTTPS فقط، TLS 1.2+، HSTS preload.
- في الراحة: AES-256 لـ DB و Storage (Supabase الافتراضي).
- مفاتيح حسّاسة (Stripe/Tap/Nafath/SMS): مشفّرة بـ libsodium داخل `api_secrets` بمفتاح master في Supabase Vault.
- تدوير المفاتيح: master key كل 90 يوماً، secrets عند الحاجة.

### الامتثال

- **PDPL (السعودية):** التزام بنظام حماية البيانات الشخصية.
  - استضافة داخل المملكة (Supabase region `me-south-1` إن متاحة، أو eu-central-1 كبديل مع اتفاقية نقل بيانات).
  - حق المستخدم في تنزيل بياناته (Export) — Edge Function `user-export-data`.
  - حق المسح (Right to be Forgotten) — Edge Function `user-delete-account` يحذف PII ويُبدّل المراجع بـ tombstone.
  - سجل معالجة شامل في `audit_log`.
- **PCI DSS:** لا نخزّن بيانات بطاقات أبداً — تُمرَّر مباشرة لمزوّد الدفع. الـ webhook فقط يستقبل توكنات.
- **App Store / Play Store / AppGallery:** privacy manifest، أذونات مبرّرة، سياسة خصوصية متاحة.

## أمان الـ API

- كل طلب يحمل JWT صالح.
- CORS مغلق إلا من نطاقات معروفة.
- CSP صارم: `default-src 'self'; img-src 'self' https://*.supabase.co https://maps.googleapis.com; ...`.
- Helmet headers على كل route handler.
- Rate limiting:
  - عام: 100 req/min/IP عبر Cloudflare.
  - مصادق: 600 req/min/user.
  - OTP: 5/hour/phone.

## Webhooks الواردة

- توقيع HMAC SHA-256 يُتحقّق منه ضد سرّ مُخزَّن في `api_secrets`.
- النوافذ الزمنية: timestamp في الـ payload ≤ 5 دقائق من الآن.
- idempotency: حفظ `event_id` في `webhook_events`.

## أمان العميل (الويب)

- لا أسرار في bundle العميل أبداً (يُفحَص بـ `secret-scan` في CI).
- httpOnly cookies للجلسة، Secure، SameSite=Lax.
- حماية CSRF: Next.js Server Actions تستخدم origin check + double-submit token.
- منع XSS: Auto-escape في React (لا `dangerouslySetInnerHTML` إلا بـ DOMPurify).
- منع clickjacking: `X-Frame-Options: DENY`.

## أمان الموبايل

- Certificate pinning لـ Supabase + Google Maps.
- التخزين الآمن: Keychain (iOS) / EncryptedSharedPreferences (Android) / Huawei Vault.
- لا logs للـ tokens.
- منع screenshot في الشاشات الحسّاسة (المدفوعات، الهوية) عبر `FLAG_SECURE`.
- jailbreak/root detection (تحذير وحظر بعض الميزات الحسّاسة).

## أمان المتاجر

- **iOS:** App Tracking Transparency، Privacy Manifest يصف الـ APIs المستخدمة، تبرير كل permission في Info.plist.
- **Android:** Data Safety form دقيقة، runtime permissions، Play Integrity API.
- **Huawei:** Permission Center + AppGallery review.

## استجابة الحوادث

- خط أحمر للأمن (Slack + PagerDuty).
- runbook في `infra/runbooks/security-incident.md` (يُكتب في المرحلة 11).
- خطة retention للسجلات: Sentry 90 يوم، Supabase logs 30 يوم، audit_log لا يُحذف.
- محاكاة سنوية للحوادث (tabletop exercise).

## مراجعات منتظمة

- مراجعة كود أمنية إلزامية لكل PR يلمس Auth/Permissions/Payments.
- اعتماد سياسة Two-person review للتغييرات في `supabase/functions/auth-*` و `supabase/migrations/*_rls_*`.
- اختبار اختراق خارجي قبل الإطلاق (المرحلة 12) ومرة سنوياً بعدها.
- تحديث تبعيات أسبوعي عبر Dependabot، مع PRs أمنية تُدمج خلال 48 ساعة.

## ما هو محظور بشدّة

- ❌ تسجيل JWT أو OTP أو رقم بطاقة في أي مكان.
- ❌ استدعاء `service_role` من كود العميل.
- ❌ `eval`, `Function()`, تنفيذ HTML غير مُعقّم.
- ❌ تجاوز RLS عبر `bypassRLS` إلا في Edge Functions موثّقة وموقّعة.
- ❌ كلمات سرّ افتراضية في أي بيئة.
- ❌ Cookies بدون Secure/HttpOnly في الإنتاج.
