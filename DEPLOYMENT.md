# دليل الإطلاق — Syanah

قائمة فحص قصيرة. لا تتجاوز عنصراً قبل تعليمه ✅.

## ١) Supabase

- [ ] أنشئ مشروع على https://supabase.com/dashboard (منطقة: Frankfurt أو Bahrain)
- [ ] **Settings → API** — انسخ المفاتيح الثلاثة:
  - `Project URL`
  - `anon public`
  - `service_role secret`
- [ ] **SQL Editor → New query** — الصق محتوى `supabase/setup.sql` كاملاً ثم **Run**
  - يُنشئ ٢٤ ترحيل + ١٣ منطقة + ~٨٠ محافظة + الأحياء + الأدوار + RLS
- [ ] **Authentication → Providers**:
  - Phone: ✅ مفعّل
  - Email: ✅ مفعّل
- [ ] **Storage → New bucket** — أنشئ أربعة:
  - `avatars` — Public
  - `chat-media` — Private
  - `portfolio` — Public
  - `dispute-evidence` — Private

## ٢) Vercel

- [ ] **Import Git Repository** (saud9495/syanah) — الفرع: `main`
- [ ] **Settings → Environment Variables** — أضف لكل البيئات (Production + Preview + Development):

  | المفتاح | المصدر |
  |---------|---------|
  | `NEXT_PUBLIC_SUPABASE_URL` | Supabase → Settings → API |
  | `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase → Settings → API |
  | `SUPABASE_SERVICE_ROLE_KEY` | Supabase → Settings → API ⚠️ |
  | `NEXT_PUBLIC_APP_URL` | `https://syanah.vercel.app` (أو دومينك) |
  | `NEXT_PUBLIC_DEFAULT_LOCALE` | `ar` |
  | `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` | Google Cloud Console |
  | `GOOGLE_MAPS_SERVER_KEY` | Google Cloud Console |
  | `GOOGLE_TRANSLATE_API_KEY` | Google Cloud Translation API |

- [ ] **Settings → Functions → Region = Frankfurt (fra1)** (أقرب لـ Supabase)
- [ ] **Deployments → Redeploy** (بدون cache) بعد كل إضافة لمتغيّر
- [ ] (اختياري) Analytics + Speed Insights = Enable

## ٣) GitHub — saud9495/syanah

كل العناصر التالية في **Settings → ...** على صفحة الريبو:

- [ ] **Branches → Add branch ruleset** على `main`:
  - Require a pull request before merging
  - Require status checks (CI · Quality, CI · Build)
  - Do not allow force pushes
- [ ] **Code security and analysis**:
  - Dependabot alerts → **Enable**
  - Dependabot security updates → **Enable**
  - Secret scanning → **Enable**
  - Push protection → **Enable**
- [ ] **Actions → General → Workflow permissions** = Read + Write
- [ ] (لو خصصت دومين) **Pages** = Disabled (لا نستخدم Pages)

> ملاحظة: ملف `.github/workflows/ci.yml` يشغّل lint + typecheck + tests + build تلقائياً لكل push.
> ملف `.github/dependabot.yml` ينشئ PRs أسبوعية للتحديثات.

## ٤) فحص أوّل تشغيل

- [ ] افتح: `https://syanah.vercel.app/ar/admin-setup`
- [ ] إذا الحالة كلها ✅ خضراء، اضغط **"ترقية حسابي لمدير عام"**
- [ ] افتح `/ar/admin/permissions` — تظهر الواجهة بدون أخطاء
- [ ] افتح `/ar/auth/sign-up` — قائمة المناطق فيها ١٣ منطقة
- [ ] افتح `/ar/providers` — يعرض المزوّدين بدون خطأ
- [ ] افتح الموقع من جوّال → ناف سفلي ٥ تابات يظهر
- [ ] **Chrome → ⋯ → Add to Home Screen** — التطبيق يثبّت كـ PWA

## ٥) محلياً (اختياري — للتطوير)

```bash
cp .env.example .env.local
# عبّئ المفاتيح
pnpm install
pnpm check:env    # يتأكد إن كل المتغيّرات موجودة
pnpm dev
```

## في حال خطأ

| الرسالة | السبب الأرجح |
|---------|--------------|
| `Supabase غير مُهيّأ` | المتغيّرات الثلاثة ناقصة في Vercel — أعد النشر بعد إضافتها |
| `auth.errors.noBackend` (مسار خام) | إصدار قديم — أعد النشر |
| القوائم فاضية في التسجيل | `supabase/setup.sql` لم يُشغَّل بعد |
| الترقية فشلت | سجّل خروج ودخول، الجلسة قديمة |
| CI أحمر | `pnpm typecheck` أو `pnpm lint` يفشل — افتح Actions tab |
