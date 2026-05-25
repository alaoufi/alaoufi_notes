# المرحلة 3 — المصادقة والأدوار — مراجعة وتوقيع

## المخرجات المُسلَّمة

### قاعدة البيانات (Supabase)

- [x] `supabase/config.toml` — إعدادات المشروع (مصادقة، تخزين، realtime، ...)
- [x] `0001_init_extensions_enums.sql` — pgcrypto/pg_trgm + enums (role، verification_method، verification_status) + `set_updated_at` trigger function.
- [x] `0002_identity_tables.sql` — profiles، user_roles، admin_sections، section_admin_assignments، devices، verifications + helper functions (`user_has_role`, `user_is_admin`).
- [x] `0003_identity_rls.sql` — تفعيل RLS على كل الجداول مع سياسات صريحة (افتراضي رفض الكل).
- [x] `0004_profile_on_signup_trigger.sql` — trigger تلقائي على `auth.users` لإنشاء profile وتعيين دور افتراضي (requester/provider فقط من ميتاداتا التسجيل؛ super_admin/section_admin يُمنحان صراحة لاحقاً).
- [x] `seed.sql` — بيانات أولية لـ admin_sections.

### كود التطبيق

- [x] عملاء Supabase: `lib/supabase/{browser,server,types,env}.ts` — clients للـ browser وserver وservice-role، مع env validation كسول لتجنّب فشل البناء.
- [x] حُرَّاس Auth: `lib/auth/guard.ts` — `getCurrentUser`, `requireUser`, `requireRole`, `hasRole`, `getCurrentRoles`.
- [x] مُحوّلات تحقّق (Adapter Pattern): `lib/auth/providers/{types,mock,index}.ts` — واجهات `OtpProvider` و `NafathProvider` مع تنفيذات mock افتراضية. التبديل لمزوّد حقيقي يتم بتغيير سطر واحد.
- [x] أخطاء موحّدة: `lib/auth/errors.ts` — `AuthError` مع `code` و `messageKey`.
- [x] Schemas للتحقّق: `features/auth/schema.ts` — zod schemas مع رسائل خطأ كمفاتيح ترجمة.
- [x] Server actions: `signUpAction`, `signInAction`, `signOutAction`.
- [x] نماذج العميل: `SignUpForm` (مع اختيار دور)، `SignInForm`.
- [x] الصفحات: `/sign-up`, `/sign-in`, `/dashboard` (محمي)، `/forbidden`.
- [x] ترجمات `auth` و `dashboard` في الخمس لغات.
- [x] `.env.example` للجذر — جميع المتغيرات المطلوبة موثّقة.

## ما يبقى مع تكاملات حقيقية (يحتاج اعتمادات خارجية)

- [ ] تكامل نفاذ الفعلي — يحتاج اعتماد من النفاذ السعودي وعقد مع مكامل.
- [ ] تكامل SMS OTP الفعلي (Taqnyat/Unifonic/Twilio) — يحتاج حساب وAPI key.
- [ ] تكامل WhatsApp Business API — يحتاج موافقة Meta + رقم تجاري.
- [ ] تفعيل MFA إلزامي للأدمن (TOTP عبر Supabase Auth) — يُفعَّل من dashboard Supabase.
- [ ] قفل بعد محاولات فاشلة — يحتاج سياسة rate-limiting في Edge Function.
- [ ] haveibeenpwned password check — يضاف عند ربط مزوّد حقيقي.

> هذه البنود **معماريّاً جاهزة**: واجهات المزوّدين معرَّفة، وnticonfig.toml يحوي خانات الإعداد. يكفي استبدال `mock` بـ adapter حقيقي.

## بوابة المرحلة 3 — نتائج الاختبار

| الفحص | النتيجة |
|---|---|
| typecheck | ✅ |
| build (53 صفحة) | ✅ |
| نموذج التسجيل يعرض في AR/EN | ✅ بصرياً |
| تبديل الدور (requester/provider) في النموذج | ✅ |
| نموذج تسجيل الدخول | ✅ |
| RLS مُفعّل على كل الجداول | ✅ في الترحيلات |
| Trigger إنشاء profile عند التسجيل | ✅ في الترحيلات |
| اختبار auth حقيقي مع Supabase live | ⚠️ يتطلّب مشروع Supabase حقيقي (يُجرى محلياً عبر `supabase start` + .env.local) |

## التوقيع الذاتي

- معتمد ذاتياً للانتقال إلى المرحلة 4.
- اختبار end-to-end الحقيقي لتدفّق المصادقة يحتاج Supabase live — يُجرى محلياً من المطوّر، وفي CI عبر Supabase preview branch.
