# المرحلة 4 — الخدمات والفئات — مراجعة وتوقيع

## المخرجات

### قاعدة البيانات

- [x] `0005_catalog_tables.sql` — categories، subcategories، services، cities، districts، providers (موسّع)، provider_categories، provider_coverage_areas. مع فهارس GIN على `services.name->>'ar'` و `'en'` لبحث trigram.
- [x] `0006_catalog_rls.sql` — قراءة عامة (active فقط) + كتابة super_admin. عرض المزوّد للعامة فقط إذا (active AND verified).
- [x] `0007_catalog_seed.sql` — 8 فئات + 24 فئة فرعية + 14 مدينة سعودية رئيسية.

### كود التطبيق

- [x] `lib/catalog/queries.ts` — استعلامات الكتالوج مع fallback آلي عند غياب env (يبقي التطوير المحلي يعمل بلا Supabase).
- [x] `components/category-icon.tsx` — خريطة آمنة من `icon_key` إلى أيقونة Lucide.
- [x] `/services` — شبكة فئات تستخدم البيانات الفعلية.
- [x] `/services/[category]` — صفحة فئة مع filters (city, rating) وفارغة عند عدم وجود مزوّدين.
- [x] `/providers` — قائمة مع نموذج بحث (q + category + city) كنموذج GET قياسي.
- [x] الصفحة الرئيسية تعرض الفئات الفعلية بدلاً من قائمة hard-coded.
- [x] ترجمات `services` و `providersList` في الخمس لغات.

## مفاتيح خوارزمية ترتيب المزوّدين (مُخطّطة)

(تُنفَّذ في view مادي في المرحلة لاحقاً مع وجود ratings الفعلية)

```
score = (
  0.40 * normalize(avg_rating_30d)
+ 0.25 * normalize(completion_rate_90d)
+ 0.15 * normalize(response_time_score)
+ 0.10 * tier_boost(subscription_tier)      -- free=0, trusted=0.5, featured=1.0
+ 0.10 * normalize(orders_total_lifetime)
)
```

- يُعاد حساب `provider_stats` كل 5 دقائق عبر `pg_cron`.
- يُكتب الـ migration الفعلي بعد توفّر بيانات تقييمات في المرحلة 8.

## بوابة المرحلة 4

| الفحص | النتيجة |
|---|---|
| typecheck | ✅ |
| build | ✅ |
| `/ar/services` يعرض 8 فئات | ✅ |
| `/ar/services/hvac` يعرض الفلاتر والـ empty state | ✅ |
| `/ar/providers` يعرض نموذج بحث كامل | ✅ |
| الفئات تعرض بالعربية في AR، بالإنجليزية في EN | ✅ |
| استعلام البحث ينتقل عبر query string | ✅ |
| Fallback يعمل بدون Supabase (مهمّ للنشر المبدئي) | ✅ |

## ملاحظات

- البحث الكامل بـ trigram سيُربط بـ Supabase الفعلي عندما تتوفّر env vars؛ الواجهة جاهزة.
- خوارزمية الترتيب تنتظر بيانات تقييمات حقيقية (المرحلة 8).
- صفحة "تفاصيل مزوّد" `/providers/[id]` تُضاف لاحقاً (تحتاج جدول providers مع بيانات حقيقية).
