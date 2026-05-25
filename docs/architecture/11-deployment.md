# 11 — النشر

## البيئات

| البيئة | الغرض | الويب | قاعدة البيانات | النطاق |
|---|---|---|---|---|
| `local` | تطوير | `pnpm dev` | Supabase Local (Docker) | http://localhost:3000 |
| `preview` | مراجعة PR | Vercel Preview | Supabase Branch DB لكل PR | `<sha>.preview.syanah.com` |
| `staging` | اختبار قبل الإنتاج | Vercel staging | Supabase staging project | `staging.syanah.com` |
| `production` | المستخدمون | Vercel production | Supabase production project | `syanah.com` + `app.syanah.com` |

## استضافة الويب (Vercel)

- مشروع Vercel واحد، 3 بيئات (Preview, Staging, Production).
- Edge Runtime للصفحات التي تستفيد منه (middleware, route handlers خفيفة).
- Node.js Runtime للصفحات التي تحتاج Node APIs.
- Image Optimization مُفعَّل مع cache headers.
- Vercel Analytics + Speed Insights للمراقبة.

## قاعدة البيانات (Supabase)

- 3 projects منفصلة: `syanah-prod`, `syanah-staging`, `syanah-dev` (مشترك لكل المطوّرين).
- Region: `me-south-1` (Bahrain) إذا متاح Supabase هناك، وإلا `eu-central-1` (Frankfurt).
- Backup tier: PITR (Point-in-Time Recovery) 7 أيام في production.
- Read replica (في الإنتاج عند الحاجة) للقراءات الثقيلة (تقارير، dashboards).

## CDN / WAF (Cloudflare)

- يقع أمام Vercel وSupabase.
- WAF rules: حماية ضد OWASP Top 10، rate limiting، bot detection.
- DNS مُدار من Cloudflare.

## DNS

| النطاق | الوجهة | الاستخدام |
|---|---|---|
| `syanah.com` | Vercel | موقع تسويقي ومدخل عام |
| `app.syanah.com` | Vercel | التطبيق الرئيسي |
| `admin.syanah.com` | Vercel | بوابة الإدارة (نفس Next.js مع subdomain routing) |
| `api.syanah.com` | Supabase | (اختياري) CNAME لـ Supabase project URL |
| `assets.syanah.com` | Cloudflare/Supabase | CDN لأصول الويب |

## CI/CD

### GitHub Actions

`/​.github/workflows/`:

| Workflow | المحفّز | الخطوات |
|---|---|---|
| `ci.yml` | كل PR | install → lint → typecheck → test → build (للويب) → migration dry-run |
| `migrations.yml` | merge to `main` | تطبيق ترحيلات Supabase على staging تلقائياً، production يدوياً بعد موافقة |
| `deploy-web.yml` | merge to `main` | يحدث آلياً عبر تكامل Vercel ↔ GitHub |
| `mobile-ci.yml` | PR يلمس `apps/mobile/**` | flutter test + flutter build (apk/ipa) في artifact |
| `release.yml` | tag `v*.*.*` | يُنشئ GitHub Release ويُشغّل Fastlane لمتاجر الموبايل |

### قواعد الفرع

- `main` محمي: لا push مباشر، PR + 1 موافقة + CI أخضر.
- `release/*` فروع إصدار للموبايل.
- Conventional commits إلزامية (commitlint).

### Migrations في الإنتاج

1. PR يحوي ملف ترحيل جديد.
2. CI يُشغّل dry-run على نسخة من staging.
3. عند merge، الترحيل يُطبَّق آلياً على staging.
4. القائد التقني يُوقّع على Slack `/deploy db prod` (GitHub Actions workflow_dispatch).
5. Production migration يُطبَّق مع backup snapshot قبل التشغيل.
6. مراقبة 30 دقيقة بعد التطبيق؛ rollback تلقائي عند زيادة معدّل الأخطاء > 2×.

### Feature Flags

- استخدام جدول `feature_flags` في DB + cache في الذاكرة.
- التبديل من الإدارة بدون نشر.
- كل ميزة جديدة تطلق خلف flag لمدة لا تقل عن 24 ساعة قبل التعميم.

## المتغيرات (Env Vars)

كل بيئة لها:

```
NEXT_PUBLIC_SUPABASE_URL=...
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...                 # خادم فقط
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=...           # مقيّد بنطاق
NEXT_PUBLIC_SENTRY_DSN=...
SENTRY_AUTH_TOKEN=...                          # CI فقط
GOOGLE_MAPS_SERVER_KEY=...                     # خادم
NAFATH_API_BASE=...
NAFATH_CLIENT_ID=...
NAFATH_CLIENT_SECRET=...
SMS_PROVIDER=taqnyat
SMS_API_KEY=...
WHATSAPP_API_TOKEN=...
PAYMENTS_PROVIDER=tap
PAYMENTS_API_SECRET=...
PAYMENTS_WEBHOOK_SECRET=...
NEXT_PUBLIC_APP_URL=https://app.syanah.com
NEXT_PUBLIC_DEFAULT_LOCALE=ar
```

- تُحفظ في Vercel Env + Supabase Vault.
- لا تتسرّب إلى bundle العميل (التي تبدأ بـ `NEXT_PUBLIC_` فقط هي المتاحة في المتصفّح).
- تُدوَّر بانتظام؛ سرّ المدفوعات والوظائف الحرجة كل 60 يوماً.

## المراقبة والتنبيهات

| الأداة | الغرض |
|---|---|
| Sentry | أخطاء الويب والموبايل والـ Edge Functions |
| Vercel Analytics + Speed Insights | Core Web Vitals، استخدام |
| Supabase Logs + Logflare | استعلامات بطيئة، أخطاء RLS |
| Cloudflare Analytics | حركة، حماية، تنبيهات DDoS |
| Grafana Cloud (اختياري) | لوحات معدّلات الطلبات والـ realtime |
| PagerDuty (إنتاج فقط) | تنبيهات حرجة 24/7 |

تنبيهات يجب إعدادها قبل الإطلاق:
- معدّل خطأ 5xx > 1% خلال 5 دقائق
- زمن استجابة P95 > 2s خلال 10 دقائق
- اتصالات Realtime > 8000 (تحذير) > 9500 (حرج)
- استخدام DB CPU > 80% لمدة 15 دقيقة
- استخدام storage > 70% من الخطة
- معدّل فشل OTP > 20% (محاولة spam)

## استمرار الأعمال (BCDR)

- RPO: 5 دقائق (PITR).
- RTO: < 1 ساعة.
- خطة rollback لكل نشر:
  - الويب: Vercel deployment rollback (نقرة).
  - DB: forward-only migrations مع scripts عكسية مُدوَّنة في PR.
  - Storage: نسخ احتياطية أسبوعية على S3 خارجي.
- اختبار استعادة كامل كل 6 أشهر، موثَّق في `infra/runbooks/disaster-recovery.md`.

## التكلفة (تقديرية، بيئة إنتاج عند إطلاق MVP)

| البند | شهرياً تقريباً |
|---|---|
| Vercel Pro Team | $40-80 |
| Supabase Pro | $25 + المتغيرات (DB compute، storage، egress) ~$200 متوقّع |
| Cloudflare Pro | $20 |
| Google Maps | يعتمد على الاستخدام؛ مع caching متوقّع $100-300 |
| Sentry Team | $26 |
| PagerDuty (إنتاج) | $20/user |
| **إجمالي تقديري** | **$500–800/شهر** عند MVP، يرتفع مع النمو |

## فحوصات قبل الإطلاق

- [ ] DNS مُفعَّل ومُختبَر.
- [ ] شهادة TLS فعّالة، HSTS preloaded.
- [ ] جميع env vars مضبوطة في production.
- [ ] backup أول مُختبَر للاستعادة.
- [ ] تنبيهات تعمل (اختبار).
- [ ] runbooks مكتوبة وموقّعة.
- [ ] sentry يستقبل أخطاء من جميع الـ services.
- [ ] webhooks مُختبَرة من sandbox الـ مزوّدين.
- [ ] التحميل تحت ضغط متوقّع.
