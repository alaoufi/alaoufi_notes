# 04 — بنية الـ API

اعتمدنا أن غالبية البيانات تأتي من **PostgREST** المُولَّد بواسطة Supabase، مع استخدام **Edge Functions** للعمليات التي تتطلّب صلاحيات إضافية أو تكاملات خارجية. هذا يُقلّل كود الـ backend المخصّص ويُسرّع التطوير دون التضحية بالأمان (RLS يفرض الحدود في قاعدة البيانات نفسها).

## طبقات الـ API

| الطبقة | الاستخدام |
|---|---|
| **Supabase Auto-generated REST** (PostgREST) | كل CRUD على الجداول العامة (طلبات، رسائل، تقييمات). الوصول محكوم بـ RLS. |
| **Supabase Realtime** | الدردشة، الحضور، الإشعارات الفورية، الموقع المباشر. |
| **Supabase Storage REST** | رفع/تنزيل الوسائط عبر signed URLs. |
| **Edge Functions (Deno)** | عمليات حسّاسة: إرسال OTP، تحقّق نفاذ، حساب ETA، تجميع تقارير، webhooks مدفوعات. |
| **Next.js Route Handlers** | فقط webhooks وproxies داخلية لا تحتاج لـ Realtime/RLS مباشرة (مثل استقبال webhook من Tap). |

## الاتفاقيات

### الإصدارات

- Edge Functions تُسمَّى بالنمط `<domain>-<action>` (مثل `auth-send-otp`, `orders-cancel`).
- التغييرات الكاسرة تتطلب نسخة جديدة مع suffix رقمي: `auth-send-otp-v2`. الإصدار القديم يبقى لمدة لا تقل عن دورة إصدار الموبايل (30 يوماً).
- PostgREST لا يحتاج إصداراً صريحاً؛ التغييرات الكاسرة في المخطط = ترحيل + نشر متزامن مع تحديث `packages/sdk`.

### نمط الطلب/الاستجابة

- نوع المحتوى: `application/json` (UTF-8).
- الترميز: `snake_case` في الجسم والمعاملات (متّسق مع أسماء أعمدة DB).
- الزمن: ISO 8601 مع منطقة (`2026-05-24T10:15:00+03:00`).
- التصفّح: `cursor` بدلاً من `offset` للقوائم الكبيرة (`?cursor=<id>&limit=20`).
- الترتيب: `?order=created_at.desc`.

### تنسيق الاستجابة

استجابة ناجحة:
```json
{
  "data": {...},
  "meta": { "next_cursor": "..." }
}
```

استجابة خطأ موحّدة:
```json
{
  "error": {
    "code": "ORDER_NOT_FOUND",
    "message_key": "errors.order_not_found",
    "details": { "order_id": "..." },
    "trace_id": "..."
  }
}
```

- `code` ثابت قابل للفحص في العميل.
- `message_key` يُستخدم في العميل لاستجلاب نص مُترجَم من `messages/*.json`.
- `trace_id` يُربط بسجلات Sentry.

### رموز الحالة (HTTP)

| الرمز | الاستخدام |
|---|---|
| 200 | نجاح مع جسم |
| 201 | إنشاء ناجح |
| 204 | نجاح بلا جسم |
| 400 | خطأ تحقّق (تفاصيل في details) |
| 401 | غير مُصادَق |
| 403 | مُصادَق لكن غير مُخوَّل |
| 404 | المورد غير موجود (أو غير مرئي للمستخدم بسبب RLS) |
| 409 | تعارض (مثل محاولة قبول طلب مقبول مسبقاً) |
| 422 | حالة عمل غير صالحة |
| 429 | تجاوز حد المعدّل |
| 5xx | خطأ خادم — تُسجَّل في Sentry وتُعيد `trace_id` |

## تحديد المعدّل (Rate Limiting)

- الجدار الأول: Cloudflare WAF (DDoS + bot).
- الجدار الثاني: حدود Supabase الافتراضية لكل JWT.
- الجدار الثالث: حدود مخصّصة على Edge Functions الحسّاسة:
  - OTP: 5 طلبات/ساعة لكل رقم.
  - فتح نزاع: 3/يوم لكل طلب.
  - إنشاء طلب: 30/ساعة لكل مستخدم.
  - رفع وسائط: 100/ساعة لكل مستخدم، 50MB إجمالي/ساعة.

## المصادقة

كل طلب لـ PostgREST أو Edge Function يحمل:
- `Authorization: Bearer <jwt>` (jwt من Supabase Auth)
- `apikey: <anon_or_service_role>` (anon للعملاء، service_role فقط داخل Edge Functions)

`service_role` JWT **لا يُسرَّب أبداً** للعميل. كل عملية تتطلّبه تمرّ عبر Edge Function.

## Realtime

### القنوات

| القناة | الاشتراك | الغرض |
|---|---|---|
| `conversation:<conversation_id>` | الطرفان في الطلب | بث رسائل جديدة |
| `presence:conversation:<conversation_id>` | الطرفان | حضور + typing |
| `order:<order_id>` | الطرفان | تحديث حالة الطلب |
| `tracking:<order_id>` | طالب الخدمة فقط | نبض موقع المزوّد |
| `notifications:user:<user_id>` | المستخدم | إشعارات داخل التطبيق |

### حدود البث

- معدّل الموقع المباشر: 1 رسالة/ثانية كحدّ أقصى (التطبيق يُجمِّع التحديثات).
- يُغلَق `tracking:*` تلقائياً عند انتقال الطلب لحالة `completed` أو `cancelled`.

## Webhooks الواردة

تُستقبل في `apps/web/app/api/webhooks/<provider>/route.ts` ثم تُمرَّر لـ Edge Function للمعالجة.

- توقيع HMAC يُتحقّق منه قبل أي معالجة.
- تخزين فوري في جدول `webhook_events` للحفاظ على idempotency.
- إعادة المحاولة مدعومة إذا فشلت المعالجة (يردّ 5xx فيُعيد المزوّد المحاولة).

أمثلة:
- `webhooks/tap/charge` — حالة دفعة من Tap
- `webhooks/whatsapp/status` — حالة تسليم رسائل WhatsApp
- `webhooks/nafath/callback` — نتيجة تحقّق نفاذ

## OpenAPI

- مستند OpenAPI 3.1 يُولَّد من تعريفات Edge Functions + مخطط PostgREST عند كل push على `main`.
- يُحفظ في `packages/sdk/openapi.yaml`.
- يُستخدم مُولّد كود Dart لتطبيق الموبايل (يُولِّد `apps/mobile/lib/data/api_client.dart`).
- يُستخدم مُولّد كود TypeScript للويب (يُولِّد `packages/sdk/src/client.ts`).

## أمثلة على Edge Functions المُخطَّط لها (لا تُكتب الآن — في مراحلها)

| الاسم | المرحلة | الوصف |
|---|---|---|
| `auth-send-otp` | 3 | إرسال OTP عبر SMS/WhatsApp |
| `auth-verify-otp` | 3 | تحقّق من OTP وإصدار جلسة |
| `auth-verify-nafath` | 3 | بدء/إكمال تحقّق نفاذ |
| `orders-create` | 7 | إنشاء طلب مع تحقّقات معقّدة (تغطية المزوّد، السعر) |
| `orders-cancel` | 7 | إلغاء مع قواعد استرداد |
| `chat-archive` | 6 | أرشفة محادثة بعد إكمال الطلب |
| `disputes-open` | 8 | فتح نزاع مع نسخ أدلّة |
| `payments-charge` | 9 | بدء عملية دفع |
| `payments-webhook` | 9 | معالجة webhook دفع |
| `notifications-send` | 7 | بثّ إشعار عبر القنوات المفضّلة |
| `stats-refresh-providers` | 4 | تحديث materialized views (cron) |
| `top-providers-monthly` | 9 | اختيار أفضل مزوّد شهرياً (cron) |
