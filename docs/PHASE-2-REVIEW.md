# المرحلة 2 — نظام التصميم UI/UX — مراجعة وتوقيع

## المخرجات المُسلَّمة

- [x] رموز التصميم (`packages/ui/src/themes/tokens.css`) — ألوان دلالية + تباعد + طباعة + أنصاف أقطار + ظلال + حركة + z-index.
- [x] محرّك ثيمات: تبديل بين `soft-blue` و `pink` عبر `[data-theme="..."]` بدون إعادة تحميل.
- [x] Tailwind preset (`packages/ui/src/tailwind-preset.ts`) يربط الرموز.
- [x] العناصر الأساسية: `Button`, `Input`, `Card` (+ Header/Title/Body/Footer), `Badge`, `Container`, `cn` helper.
- [x] التخطيط: SiteHeader (لاصق + شفافية)، SiteFooter، أقسام (Hero, Categories, HowItWorks, ProvidersCta).
- [x] دعم RTL/LTR: `<html dir>` ديناميكي بحسب اللغة، استخدام خصائص logical (`ms-`, `me-`, `start-`, `end-`).
- [x] ترجمات كاملة في الخمس لغات (`messages/{ar,ur,en,hi,bn}.json`).
- [x] صفحات أساسية: `/`, `/services`, `/providers`, `/how-it-works`, `/sign-in`, `/sign-up`, `/become-provider`, `/privacy`, `/terms`, `/contact`, `not-found`.

## بوابة المرحلة 2 — نتائج الاختبار

| الفحص | النتيجة |
|---|---|
| typecheck (`pnpm typecheck`) | ✅ نظيف، صفر أخطاء |
| build (`pnpm build`) | ✅ نجح، 53 صفحة ثابتة |
| تجريب يدوي AR (RTL، soft-blue) | ✅ |
| تجريب يدوي AR (RTL، pink — cookie) | ✅ تبديل الثيم بدون إعادة تحميل |
| تجريب يدوي UR (RTL) | ✅ |
| تجريب يدوي EN (LTR) | ✅ |
| تجريب يدوي HI (LTR) | ✅ |
| تجريب يدوي BN (LTR) | ✅ |
| 404 ينتج 404 status | ✅ |
| توجيه `/` إلى `/ar` | ✅ (307) |

## ملاحظات

- خط Tailwind v3 (لا v4 بعد) لاستقرار الـ presets.
- ألوان الثيمين مُرشَّحة وتقبل التعديل من المصمم لاحقاً بتعديل ملف `tokens.css` فقط — لا تعديل في العناصر الأساسية.
- تجربة المستخدم على الجوال مُختبَرة بصرياً عند 1280px فقط حتى الآن؛ اختبار جهاز حقيقي يبقى مفتوحاً قبل الإطلاق.
- إمكانية الوصول: تركيز مرئي بـ `*:focus-visible`، أزرار لها `aria-busy` و `aria-haspopup`. تدقيق axe-core يُضاف في المرحلة 12.

## التوقيع الذاتي

- معتمد ذاتياً للانتقال إلى المرحلة 3 بناءً على توجيه مالك المنتج "لا توقف حتى تكتمل كافة المراحل مع المراجعة".
- التوقيع الرسمي من مالك المنتج/القائد التقني/المراجع الأمني/مسؤول DB لا يزال مطلوباً قبل الإطلاق النهائي.
