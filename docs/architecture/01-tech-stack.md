# 01 — الحزمة التقنية

كل خيار هنا **مُقفَل** عند توقيع المرحلة 1. أي تغيير لاحق يحتاج تعديلاً موثّقاً.

## الويب

| الموضوع | الخيار | المبرّر |
|---|---|---|
| الإطار | Next.js 15 (App Router) | React حديث، RSC للأداء، توجيه قائم على الملفات، تكامل ناضج مع Vercel. |
| اللغة | TypeScript (strict) | أمان أنواع على الويب والحزم المشتركة. |
| التصميم | Tailwind CSS + متغيرات CSS | سرعة الـ utility-first مع ثيمات مدفوعة بالـ tokens (بلا ألوان مُضمَّنة). |
| إدارة الحالة (العميل) | React Server Components + Zustand لحالة العميل | RSC للبيانات الخادمية، Zustand لحالة العميل الخفيفة. |
| جلب البيانات | Server Components + `@tanstack/react-query` للعميل | RSC للتحميل الأول، react-query للتغييرات وإعادة التحقق على العميل. |
| النماذج | `react-hook-form` + `zod` | أداء عالٍ، تحقق بالـ schemas. |
| Realtime على العميل | `@supabase/supabase-js` | قنوات Supabase Realtime الأصلية. |
| الترجمة (i18n) | `next-intl` | متوافق مع App Router، يعتمد رسائل، يدعم RTL/LTR. |
| الخرائط | `@vis.gl/react-google-maps` | غلاف React حديث لـ Google Maps. |
| الرسوم البيانية (الإدارة) | `recharts` | خفيف، صديق للـ RTL. |
| الأيقونات | `lucide-react` | قابل لإزالة الشجرة (tree-shake)، متسق. |

## الخلفية / البيانات

| الموضوع | الخيار | المبرّر |
|---|---|---|
| قاعدة البيانات | Supabase (Postgres 16 مُدارة) | قوة Postgres، RLS، APIs مولّدة، Realtime، Auth، Storage في منصة واحدة. |
| المصادقة | Supabase Auth + مُحوّلات تحقّق مخصّصة | OTP/نفاذ/WhatsApp/بريد مغلّفة خلف جدول مستخدمي Supabase. |
| التفويض | RLS في Postgres + فحوصات صلاحيات في الخادم | دفاع متعدّد الطبقات — قاعدة البيانات تُلزم، والخادم يُؤكّد. |
| Realtime | Supabase Realtime (نسخ Postgres + قنوات broadcast) | الدردشة والحضور والموقع المباشر تستخدم نفس طبقة القنوات. |
| التخزين | Supabase Storage (مدعوم بـ S3) | حاويات خاصة، Signed URLs، متكامل مع Auth. |
| المهام الخلفية | Supabase Edge Functions + `pg_cron` للجدولة | كل شيء داخل Supabase، بلا بنية تحتية إضافية. |
| البحث | Postgres full-text + `pg_trgm` (v1)؛ الانتقال إلى Meilisearch فقط عند الحاجة | تجنّب التعقيد المبكّر؛ trigram + GIN يكفي لحجم MVP. |
| الترحيلات | Supabase CLI (`supabase migration`) | SQL مُؤرشف، قابل للمراجعة، يعاد تشغيله في CI. |

## الموبايل (مؤجّل للمرحلة 11)

| الموضوع | الخيار | المبرّر |
|---|---|---|
| الإطار | Flutter | قاعدة كود واحدة لـ iOS وAndroid وHuawei. دعم عربي قوي. |
| المعمارية | Clean Architecture + Riverpod | قابلة للاختبار، تتسع للفريق. |
| عميل API | مُولَّد من OpenAPI (من المرحلة 4 فصاعداً) | مصدر حقيقة واحد مع الخلفية. |
| الخرائط | `google_maps_flutter` (iOS/Android)، `huawei_map` (Huawei) | تكافؤ أصلي لكل منصّة. |
| الإشعارات | FCM (iOS/Android) + HMS Push (Huawei) | أصلي لكل متجر. |
| تقارير الأعطال | Sentry | متجانس مع الويب. |

## البنية التحتية

| الموضوع | الخيار | المبرّر |
|---|---|---|
| استضافة الويب | Vercel | دعم من الدرجة الأولى لـ Next.js، edge runtime، preview deploys. |
| استضافة البيانات | Supabase Cloud | Postgres + Realtime + Storage + Auth مُدارة. |
| DNS / CDN | Cloudflare (أمام Vercel) | حماية DDoS، WAF، تحسين صور احتياطي. |
| الأسرار | متغيرات Vercel + أسرار Supabase + 1Password vault للفريق | لا أسرار في المستودع أبداً. |
| المراقبة | Vercel Analytics + Sentry + Supabase logs + Grafana Cloud (اختياري) | قياس واجهة + خلفية + قاعدة بيانات. |
| التكامل المستمر (CI) | GitHub Actions | lint، typecheck، تشغيل اختبارات، build، فحص ترحيلات لكل PR. |

## خدمات طرف ثالث (الاختيار النهائي يتم في مرحلتها)

| الخدمة | المرشّحون | مرحلة الحسم |
|---|---|---|
| SMS OTP | Taqnyat, Unifonic, Twilio | المرحلة 3 |
| WhatsApp OTP | Meta WhatsApp Business API, Unifonic | المرحلة 3 |
| نفاذ | API حكومي سعودي (عبر مكامل رسمي) | المرحلة 3 |
| المدفوعات | Tap, Moyasar, HyperPay | المرحلة 9 |
| الخرائط | Google Maps Platform (مُقفل) | المرحلة 1 |

## خارج الاعتبار (مرفوض صراحةً)

- **Firebase / Firestore كقاعدة بيانات رئيسية** — NoSQL لا يناسب المتطلّبات العلائقية (طلبات، نزاعات، تقييمات، عمولات).
- **خادم Node.js مخصّص** — يضيف عبء بنية تحتية مقابل Supabase APIs المولّدة + Edge Functions. يمكن إضافته لاحقاً فقط عند الحاجة.
- **React Native** — اخترنا Flutter لدعم أفضل لـ Huawei AppGallery واتساق UI عبر الأجهزة.
- **MongoDB** — نفس سبب Firestore.
- **Postgres ذاتي الاستضافة على VM** — التكلفة التشغيلية مرتفعة قبل تحقّق Product-Market Fit.
