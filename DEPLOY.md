# نشر صيانة على Vercel

المشروع monorepo (الكود في `apps/web/`). يجب إخبار Vercel كيف يبني.

## الطريقة المُوصى بها — إعداد Root Directory (الأنظف)

1. افتح مشروعك في Vercel → **Settings** → **General**.
2. ابحث عن **Root Directory** → اضغط **Edit**.
3. اكتب: `apps/web`
4. **اترك** خيار "Include source files outside of the Root Directory" مفعّلاً (مهمّ — يُضمّن `packages/ui` و `pnpm-workspace.yaml`).
5. **Save**.
6. ارجع للـ **Deployments** → اضغط على آخر deploy → **Redeploy** → اختر "Use existing Build Cache: No".

سيكتشف Vercel Next.js تلقائياً ويستخدم pnpm. كل شيء يعمل دون تعديل ملفات.

## الطريقة البديلة — `vercel.json` (مُضمَّن في الـ repo)

ملف `vercel.json` موجود الآن في جذر المستودع ويفعّل:

```json
{
  "framework": "nextjs",
  "buildCommand": "pnpm --filter @syanah/web build",
  "installCommand": "pnpm install --no-frozen-lockfile",
  "outputDirectory": "apps/web/.next"
}
```

إذا لم تستطع تعديل Root Directory من الـ Dashboard:
1. تأكّد أن Vercel يستخدم branch `claude/syanah-new-project-2KpvG` (أو ادمج للـ `main` أولاً).
2. اضغط Redeploy.

## التحقّق من نجاح النشر

بعد الـ deploy الناجح، الروابط التالية يجب أن تعمل:

- `/` → يحوّلك إلى `/ar` (مع status 307)
- `/ar` — الصفحة الرئيسية بالعربية، اتجاه RTL
- `/en`, `/ur`, `/hi`, `/bn` — اللغات الأربع الأخرى
- `/ar/services` — قائمة الفئات
- `/ar/orders` — قائمة الطلبات (بيانات نموذجية)
- `/ar/orders/new` — معالج الطلب الجديد
- `/ar/pricing` — صفحة الباقات
- `/ar/admin` — لوحة الإدارة (تعمل بدون Supabase في preview)

## متغيّرات البيئة (لتفعيل الميزات الحيّة)

في Vercel → Settings → Environment Variables، أضف:

```
NEXT_PUBLIC_SUPABASE_URL          = <من Supabase>
NEXT_PUBLIC_SUPABASE_ANON_KEY     = <من Supabase>
SUPABASE_SERVICE_ROLE_KEY         = <من Supabase — Production فقط، حساس>
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY   = <لتفعيل الخرائط>
```

بدون هذه القيم، الموقع يعمل كاملاً مع بيانات نموذجية (fallback) للعرض.

## استكشاف الأخطاء

| العَرَض | السبب الأرجح | الحل |
|---|---|---|
| 404 على كل الصفحات بعد build ناجح | Vercel بنى من جذر فارغ | اضبط Root Directory = `apps/web` |
| "Cannot find module @syanah/ui" | "Include source files outside Root Directory" غير مفعّل | فعّله من الإعدادات |
| Build يفشل بـ "supabase env missing" | نسخة قديمة من الكود | اسحب آخر commit `6ebe252` أو أحدث |
| الصفحة بيضاء | غالباً JS لم يُحمّل | افحص Console — أرسل لي الخطأ |
