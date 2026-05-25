# دليل ربط Supabase بـ Syanah على Vercel

كل اللي تحتاجه في خمس خطوات. الوقت المتوقع: ٥–٧ دقائق.

---

## 1) أنشئ مشروع Supabase

1. ادخل https://supabase.com/dashboard
2. اضغط **New project**
3. اختر منطقة قريبة (Frankfurt أو Bahrain للسعودية)
4. خزّن كلمة مرور قاعدة البيانات (ما نحتاجها الحين لكن لا تضيعها)
5. انتظر دقيقتين حتى يجهز المشروع

## 2) خذ المفاتيح الثلاثة

من لوحة Supabase: **Settings → API**

| المفتاح | الاسم في Vercel |
|--------|------------------|
| `Project URL` | `NEXT_PUBLIC_SUPABASE_URL` |
| `anon public` | `NEXT_PUBLIC_SUPABASE_ANON_KEY` |
| `service_role secret` | `SUPABASE_SERVICE_ROLE_KEY` |

> ⚠️ مفتاح `service_role` خطير — لا تنشره ولا تخليه في كود الواجهة. عندنا يُستخدم فقط في Server Actions.

## 3) أضف المتغيّرات في Vercel

من مشروع Syanah على Vercel:

**Settings → Environment Variables**

أضف الثلاثة كلهم لبيئات **Production + Preview + Development**:

```
NEXT_PUBLIC_SUPABASE_URL       = https://xxxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY  = eyJhbGciOi...
SUPABASE_SERVICE_ROLE_KEY      = eyJhbGciOi...
```

## 4) شغّل سكربت قاعدة البيانات

1. افتح `supabase/setup.sql` من هذا الريبو
2. انسخ محتواه كامل
3. في Supabase: **SQL Editor → New query**
4. الصق وشغّل (**Run** أو Ctrl+Enter)

السكربت يحتوي على الترحيلات الـ23 بترتيبها وآمن للتشغيل المتكرر. سيُنشئ:
- الجداول كلها (الهوية، الفئات، الطلبات، المحادثات، التقييمات…)
- ١٣ منطقة سعودية + ~٨٠ محافظة + المدن الكبرى + ٨٥ حي
- تفعيل أربع مناطق رئيسية (الرياض، مكة، المدينة، الشرقية)
- دالة `bootstrap_super_admin()` لترقية أول مدير

## 5) أعد نشر Vercel وادخل لوحة التحكم

1. في Vercel: **Deployments → آخر نشر → ⋯ → Redeploy** (بدون cache)
2. بعد ما يطلع جاهز، روح:

   ```
   https://syanah.vercel.app/ar/admin-setup
   ```

3. أنشئ حساب أو سجّل دخول (الزرار في أعلى الصفحة)
4. ارجع لنفس الرابط واضغط **ترقية حسابي لمدير عام**
5. تحوّل تلقائياً إلى `/ar/admin`

---

## التحقق السريع من النجاح

| التحقق | الناتج المتوقع |
|---------|-----------------|
| `/ar/admin-setup` | كل الشروط ✅ خضراء |
| `/ar/auth/sign-up` | يظهر اختيار المنطقة والمحافظة والمدينة |
| `/ar/providers` | يفتح بدون أخطاء |
| `/ar/admin/translations` | تبويب الترجمات يفتح ويعرض الجمل |

## إصلاح المشاكل

- **"Supabase غير مُهيّأ"** → المتغيّرات لم تُضف في Vercel أو لم تُعِد النشر بعد إضافتها
- **"لا توجد مناطق"** → سكربت `setup.sql` لم يُشغَّل بعد، أو شُغِّل قبل إضافة المتغيّرات
- **"ترقية فشلت"** → سجّل خروج ودخول مرّة ثانية، الجلسة قد تكون قديمة
