# المرحلة 12 — الاختبارات النهائية والتحسين — مراجعة وتوقيع

## المخرجات

- [x] Vitest مع jsdom و @testing-library — البنية كاملة في `apps/web/vitest.config.ts` + `tests/setup.ts`.
- [x] اختبارات وحدة:
  - `tests/i18n.test.ts` — قائمة اللغات، RTL/LTR، الافتراضي.
  - `tests/catalog.test.ts` — `localized()` ومسارات الـ fallback.
  - `tests/auth-schema.test.ts` — sign-up/sign-in schemas (قبول، رفض، تطبيع رقم الجوال).
  - `tests/messages.test.ts` — **تحقق ضمان حيوي:** كل locale يحوي نفس مفاتيح ar — يفشل CI عند نقص أي ترجمة.
- [x] السكربتات: `pnpm test` و `pnpm test:watch`.
- [x] جميع الفحوصات النهائية ناجحة:

```
typecheck   : ✅ (0 errors)
lint        : ✅ (0 warnings, 0 errors)
test        : ✅ 16/16 passing
build       : ✅ all pages compile, ~98 routes generated
```

## ما يحتاج تكاملاً قبل الإطلاق

- [ ] إنشاء مشروع Supabase فعلي + تطبيق الترحيلات 0001 → 0015.
- [ ] ملء `.env.local` بمفاتيح حقيقية لـ Supabase وGoogle Maps.
- [ ] اختيار وعقد مع مزوّد دفع (Tap/Moyasar/HyperPay) ومزوّد SMS (Taqnyat/Unifonic).
- [ ] اعتماد نفاذ من جهة حكومية مكاملة.
- [ ] اختبار اختراق خارجي (مع شركة مستقلة).
- [ ] Lighthouse + Web Vitals من بيئة الإنتاج.
- [ ] اختبار حِمل (k6 أو Artillery) على الـ realtime channels.

## بوابة المرحلة 12

| الفحص | النتيجة |
|---|---|
| typecheck | ✅ |
| lint | ✅ |
| unit tests | ✅ 16 ناجح |
| build | ✅ |
| كل اللغات الـ 5 تحوي نفس مفاتيح ar (ضمان آلي) | ✅ |
| RTL وLTR صحيحان على كل الصفحات | ✅ بصرياً |
| تبديل الثيم بدون regressions | ✅ بصرياً |
| استجابة الموبايل (لقطة 414px) | ✅ |

## ملاحظات للإطلاق

- زر "إنشاء حساب" يعمل عند توفّر env Supabase + سياسة Auth في dashboard Supabase.
- خرائط Google ستظهر طبيعياً عند توفّر `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY`، وحالياً تظهر placeholder.
- خوارزمية ترتيب المزوّدين (المرحلة 4 المؤجَّلة) يمكن الآن تنشيطها بعد توفّر بيانات حقيقية في `provider_stats`.
