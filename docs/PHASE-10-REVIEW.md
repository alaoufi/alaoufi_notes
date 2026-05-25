# المرحلة 10 — الإعدادات والترجمات (إدارة) — مراجعة وتوقيع

## المخرجات

### قاعدة البيانات

- [x] `0015_cms_settings_audit.sql`:
  - `translations` (key، locale، value) — تتجاوز `messages/*.json` المُجمَّعة.
  - `message_templates` لقوالب SMS/WhatsApp/Email/Push (مع متغيّرات).
  - `settings` لـ key/value config (locale افتراضي، نوافذ، حدود).
  - **Seed** لإعدادات أساسية (default_locale، cancel_window_minutes، dispute window، إلخ).
  - `api_secrets` — مشفّرة على مستوى التطبيق، RLS=deny للجميع (يُقرأ من service_role فقط).
  - `audit_log` — قراءة للأدمن فقط، إدراج من service_role فقط.
  - RLS كامل: قراءة الترجمات للجميع (لتحديث live)، الكتابة للأدمن.

### كود التطبيق

- [x] `/admin` shell مع شريط جانبي لـ 6 أقسام (Overview, Categories, Users, Disputes, Translations, Settings).
- [x] **Guard:** `requireRole(["super_admin", "section_admin"])` تلقائي على كل `/admin/*` (يُتجاوز فقط في preview بلا Supabase env).
- [x] `/admin` — KPIs cards + لوحة آخر النشاط.
- [x] `/admin/categories` — قائمة الفئات مع زرّ "إضافة" و"تعديل".
- [x] `/admin/users` — قائمة مستخدمين مع شارات الدور والتحقّق.
- [x] `/admin/disputes` — مركز النزاعات مع حالة وإجراء "مراجعة".
- [x] `/admin/translations` — جدول مفاتيح × لغات قابل للتعديل (CMS).
- [x] `/admin/settings` — إعدادات التطبيق + خانات مفاتيح API (مُخفية).
- [x] ترجمات `admin` كاملة في الخمس لغات.

## ما يحتاج تكاملاً حقيقياً

- [ ] Server actions حقيقية لكل صفحة إدارة (CRUD على الجداول).
- [ ] Edge Function `cms-translations-bulk-import` لاستيراد CSV.
- [ ] Edge Function `secrets-rotate` لتدوير المفاتيح آلياً.
- [ ] Real-time tray للإشعارات الإدارية.

## بوابة المرحلة 10

| الفحص | النتيجة |
|---|---|
| typecheck | ✅ |
| build | ✅ |
| Guard يحمي /admin بدور صحيح | ✅ في الكود |
| الشريط الجانبي مع 6 أقسام | ✅ |
| محرّر ترجمات بصيغة جدول | ✅ |
| settings تخفي المفاتيح الحسّاسة | ✅ (type=password) |
| audit_log غير قابل للحذف عبر RLS | ✅ |

## ملاحظات

- جدول `audit_log` يُكتب فيه من triggers و Edge Functions فقط — لا UI لإضافة سجلات يدوية (تصميم متعمَّد).
- مفاتيح API لا تُعرض في GET — الـ admin يكتب فقط، والتحقّق من النجاح يكون بنجاح آخر استدعاء.
