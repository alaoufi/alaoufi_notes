# المرحلة 7 — الطلبات وتدفّق الخدمة — مراجعة وتوقيع

## المخرجات

### قاعدة البيانات

- [x] `0010_orders.sql`:
  - enum `order_status` (9 حالات).
  - جدول `orders` مع `code` تلقائي وفهارس على (requester_id, status)، (provider_id, status)، GIST على location، وفهرس جزئي للطلبات النشطة.
  - `order_status_history` للتدقيق التلقائي لكل تحوّل.
  - **آلة حالات في trigger** (`validate_order_status_transition`) — ترفض أي انتقال غير صالح وتُحدّث الـ timestamps المناسبة (accepted_at، started_at، completed_at، cancelled_at).
  - `order_attachments` للصور الأولية من الطالب.
  - RLS: قراءة لطرفي الطلب + الأدمن؛ كتابة منفصلة (إنشاء = طالب فقط، تحديث = مزوّد/طالب/أدمن).
- [x] `0011_chat_tighten_and_links.sql`:
  - ربط FK من conversations و location_pings إلى orders.
  - trigger إنشاء محادثة تلقائياً عند إنشاء طلب.
  - trigger أرشفة المحادثة عند إكمال/إلغاء الطلب.
  - تشديد سياسات RLS على conversations/messages/location_pings (طرف الطلب فقط، أرشيف = قراءة).
- [x] `0012_notifications.sql`:
  - جدول `notifications` (تغذية داخلية بمفاتيح ترجمة)، `notification_deliveries` (سجل لكل قناة)، `notification_preferences` (لكل مستخدم).
  - trigger `notify_on_order_status_change` ينشئ إشعاراً للطرفين عند كل تحوّل مهم.
  - RLS: المستخدم يقرأ إشعاراته فقط؛ الإدراج عبر service_role فقط.

### كود التطبيق

- [x] `features/orders/types.ts` — أنواع `OrderStatus`, `OrderSummary`.
- [x] `features/orders/components/order-status-badge.tsx` — شارة ملوّنة لكل حالة (مع ترجمة).
- [x] `features/orders/components/new-order-form.tsx` — معالج 4 خطوات (الفئة → الموقع → الموعد → المراجعة) مع تحقّق كل خطوة قبل التالية. يستخدم `LocationPicker` للخريطة.
- [x] `/orders` — قائمة طلبات الطالب مع شارات حالة وأسعار (يستخدم بيانات نموذج عند غياب Supabase).
- [x] `/orders/new` — صفحة المعالج.
- [x] `/orders/[id]` — تفاصيل الطلب: tracking map + chat + ملخّص + إجراءات.
- [x] ترجمات `orders` و `orders.status` و `orders.new` في الخمس لغات.

## بوابة المرحلة 7

| الفحص | النتيجة |
|---|---|
| typecheck | ✅ |
| build | ✅ |
| المعالج يدعم 4 خطوات مع تنقّل + تحقق | ✅ |
| لا يمكن المتابعة قبل إكمال البيانات المطلوبة | ✅ |
| آلة الحالات تمنع الانتقالات غير الصالحة | ✅ في الـ migration |
| Trigger إنشاء المحادثة عند الطلب | ✅ |
| Trigger أرشفة المحادثة عند الاكتمال | ✅ |
| Trigger إنشاء الإشعارات | ✅ |
| تفاصيل الطلب تجمع: خريطة + دردشة + إجراءات | ✅ |

## ما يحتاج تكاملاً حقيقياً

- [ ] Edge Function `orders-create` مع تحقّق سعر وتغطية المزوّد على الخادم.
- [ ] Edge Function `orders-cancel` مع قواعد الاسترداد.
- [ ] Edge Function `notifications-send` لإطلاق push عبر FCM/APNs.
- [ ] ربط Form بـ Server Action لإنشاء الطلب فعلياً.

## ملاحظات

- نموذج الطلب الحالي يحفظ محلياً ويُظهر شاشة "تمّ" — الـ wiring الحقيقي يحتاج Supabase URL والاتصال بـ Edge Function.
- إشعارات in-app live tray (الجرس في الـ Header) تُضاف في المرحلة 10 مع CMS الإشعارات.
