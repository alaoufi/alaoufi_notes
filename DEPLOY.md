# نشر صيانة على Vercel

المشروع monorepo (الكود في `apps/web/`). الطريقة الصحيحة لنشره على Vercel تتطلّب إعداداً واحداً فقط من الـ Dashboard.

## الخطوات الإلزامية

### 1) اضبط Root Directory

1. افتح مشروعك في Vercel → **Settings** → **General**.
2. ابحث عن قسم **Root Directory** → اضغط **Edit**.
3. اكتب بالضبط: `apps/web`
4. تأكّد أن **"Include source files outside of the Root Directory"** مُفعَّل ✓
   (مهمّ جداً — بدونه Vercel ما يضمّ `packages/ui` و `pnpm-workspace.yaml`).
5. اضغط **Save**.

### 2) تأكّد من Production Branch

1. **Settings** → **Git**
2. **Production Branch** = `claude/syanah-new-project-2KpvG`
3. **Save** إن غيّرت.

### 3) أضف متغيّرات البيئة (اختياري — تفعّل الميزات الحيّة)

**Settings** → **Environment Variables** — أضف لكل من Production و Preview:

```
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY   = <مفتاح Google Maps>      (لتفعيل الخرائط)
NEXT_PUBLIC_SUPABASE_URL          = https://xxxx.supabase.co   (لتفعيل المصادقة)
NEXT_PUBLIC_SUPABASE_ANON_KEY     = eyJ...                     (anon key)
SUPABASE_SERVICE_ROLE_KEY         = eyJ...                     (Production فقط، حسّاس)
```

بدونها: الموقع يعمل كاملاً مع بيانات نموذجية fallback.

### 4) أعد النشر (Redeploy)

1. **Deployments** → آخر deploy → النقاط الثلاث `⋯` → **Redeploy**
2. **مهمّ:** اختر "Use existing Build Cache: **No**" لإعادة بناء كامل بعد أي تغيير في الإعدادات.

## ماذا يحدث تلقائياً بعد ضبط Root Directory

Vercel سوف:
- يكتشف Next.js من `apps/web/package.json` ✓
- يكتشف pnpm من `pnpm-lock.yaml` و `pnpm-workspace.yaml` ✓
- يُشغّل `pnpm install` على الجذر (يُثبّت كل الـ workspace)
- يُشغّل `next build` داخل `apps/web`
- ينشر الـ output بشكل صحيح مع routes و middleware و serverless functions

لا تحتاج `vercel.json` ولا أي ملف إعداد إضافي.

## التحقّق من نجاح النشر

| الرابط | المتوقّع |
|---|---|
| `https://syanah.vercel.app/` | تحويل 307 إلى `/ar` |
| `https://syanah.vercel.app/ar` | الصفحة الرئيسية بالعربية، RTL |
| `https://syanah.vercel.app/en` | بالإنجليزية، LTR |
| `https://syanah.vercel.app/ar/services` | قائمة الفئات |
| `https://syanah.vercel.app/ar/orders/new` | معالج طلب جديد |
| `https://syanah.vercel.app/ar/pricing` | باقات المزوّدين |
| `https://syanah.vercel.app/ar/admin` | لوحة الإدارة (تعمل بدون Supabase) |
| `https://syanah.vercel.app/ar/map-demo` | خريطة Google (يحتاج المفتاح) |

## استكشاف الأخطاء

| العَرَض | السبب الأرجح | الحل |
|---|---|---|
| `No Next.js version detected` | Root Directory = الجذر، لم يُضبط على `apps/web` | اتبع الخطوة 1 أعلاه |
| `Cannot find module @syanah/ui` | "Include source files outside Root Directory" مُعطَّل | فعّله من الإعدادات |
| `DEPLOYMENT_NOT_FOUND` | Production Branch خاطئ، أو لم يوجد deploy ناجح | اتبع الخطوة 2 ثم Redeploy |
| 404 على كل الصفحات بعد build ناجح | إعداد قديم من vercel.json (محذوف الآن) | Redeploy بدون cache |
| خريطة لا تظهر | `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` غير مضبوط، أو لم يُعَد البناء بعد إضافته | Redeploy بدون cache |
