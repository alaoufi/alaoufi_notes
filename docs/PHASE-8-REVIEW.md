# المرحلة 8 — التقييمات والنزاعات — مراجعة وتوقيع

## المخرجات

### قاعدة البيانات

- [x] `0013_ratings_disputes.sql`:
  - `ratings` — تقييمات ثنائية الاتجاه (طالب ↔ مزوّد)، حد أقصى تقييم واحد لكل (طلب، مُقيِّم).
  - `disputes` — نزاع واحد لكل طلب، مع `status` enum من 5 حالات.
  - `dispute_evidence` — تجمع أنواع الأدلة (chat_export, message, photo, audio, other).
  - `dispute_actions` — سجل تدقيق لإجراءات الإدارة.
  - **Trigger** `toggle_ratings_visibility_on_dispute` — يخفي/يظهر التقييمات تلقائياً.
  - **Trigger** `mark_order_disputed` — ينقل الطلب لحالة `disputed`.
  - **Materialized view** `provider_stats` — متوسط التقييم، عدد التقييمات، عدد الطلبات المكتملة، إلغاءات المزوّد.
  - RLS صارم: تقييم لطرف طلب مكتمل وبدون نزاع نشط فقط، تعديل النزاع للأدمن فقط.

### كود التطبيق

- [x] `features/ratings/components/star-rating.tsx` — مكوّن نجوم تفاعلي (RTL-safe، keyboard-friendly).
- [x] `features/ratings/components/rating-form.tsx` — نموذج تقييم مع تعليق وحدّ 2000 حرف.
- [x] `features/disputes/components/dispute-form.tsx` — نموذج فتح نزاع مع تحقّق طول.
- [x] `/orders/[id]/rate` — صفحة التقييم.
- [x] `/orders/[id]/dispute` — صفحة فتح النزاع.
- [x] ترجمات `ratings` و `disputes` في الخمس لغات.

## بوابة المرحلة 8

| الفحص | النتيجة |
|---|---|
| typecheck | ✅ |
| build | ✅ |
| تقييم بنجوم تفاعلي | ✅ |
| نموذج النزاع له تحقّق طول السبب | ✅ |
| تشغيل آلي للحجب عند فتح نزاع | ✅ في الـ migration |
| Materialized view للإحصائيات | ✅ |

## ملاحظات

- لوحة مركز النزاعات للإدارة تُبنى في المرحلة 10 ضمن الـ admin CMS.
- خوارزمية ترتيب المزوّدين (Phase 4 المُؤجَّلة) يمكن الآن تنفيذها بعد توفّر `provider_stats`.
- ترجمة المراجعات تلقائياً تتطلب تكامل مع API ترجمة — تُضاف لاحقاً.
