# المرحلة 5 — الخرائط والموقع المباشر — مراجعة وتوقيع

## المخرجات

### قاعدة البيانات

- [x] `0008_geo_and_location_pings.sql`:
  - تفعيل امتداد `postgis` (يحتاج تفعيل في Supabase Dashboard).
  - إضافة `current_location` و `current_location_updated_at` إلى `providers`.
  - فهرس GIST على `providers.current_location`.
  - جدول `location_pings` (append-only) لتدفّق المواقع أثناء الطلبات النشطة.
  - دالة `providers_nearby(lat, lng, radius, category)` لاستعلام Top-K المزوّدين الأقرب.
  - RLS مفعّل على `location_pings` (المزوّد يكتب الخاصة به فقط).

### كود التطبيق

- [x] `@vis.gl/react-google-maps` مضاف (Next.js-friendly).
- [x] `components/map/map-env.ts` — قراءة آمنة لمفتاح Google Maps.
- [x] `components/map/map-fallback.tsx` — بديل بصري نظيف حين يغيب المفتاح.
- [x] `components/map/location-picker.tsx` — مكوّن لاختيار الموقع بنقرة على الخريطة، مع علامة قابلة للسحب.
- [x] `components/map/tracking-map.tsx` — عرض موقع المزوّد + الوجهة، مع تتبّع تلقائي للمركز.
- [x] صفحة `/[locale]/map-demo` لعرض المكوّن (وتأكيد عدم الانكسار بدون مفتاح).
- [x] ترجمات `mapDemo` في الخمس لغات.

## ما يحتاج إعداد خارجي

- [ ] إنشاء مشروع Google Cloud + تفعيل Maps JavaScript API + Places API.
- [ ] إنشاء API key مقيّد بنطاق `*.syanah.com` و `localhost`.
- [ ] إضافة `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` في Vercel + `.env.local`.
- [ ] إضافة `GOOGLE_MAPS_SERVER_KEY` (مفتاح غير مقيّد بـ origin) لاستعلامات الخادم (geocoding, distance matrix).
- [ ] تفعيل امتداد `postgis` من Supabase Dashboard قبل تطبيق `0008_*`.

## الموقع الحقيقي (Live broadcast)

- المزوّد سيبث نبضة موقع كل 5 ثوانٍ عبر قناة `tracking:<order_id>` (Supabase Realtime broadcast).
- العميل (طالب الخدمة) يشترك في القناة ويُحدّث الخريطة.
- يُكتب hook `useProviderTracking(orderId)` في المرحلة 7 مع توفّر الطلبات.

## بوابة المرحلة 5

| الفحص | النتيجة |
|---|---|
| typecheck | ✅ |
| build | ✅ |
| المكوّن يعمل بدون مفتاح (fallback) | ✅ |
| الميجريشن صالح SQL | ✅ بنية مراجعة |
| الفهارس GIST موجودة | ✅ |
| RLS على pings مُفعّل | ✅ |

## ملاحظات

- تتبّع البطّارية والـ background location مسألة Flutter بحتة (المرحلة 11).
- خصوصية الموقع: الواجهة لا تطلب الموقع حتى يبدأ طلب نشط (سيتم تعزيزها في المرحلة 7).
