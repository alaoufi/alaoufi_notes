# المرحلة 9 — الإعلانات والاشتراكات — مراجعة وتوقيع

## المخرجات

### قاعدة البيانات

- [x] `0014_subscriptions_ads_payments.sql`:
  - `subscription_packages` (free, trusted, featured) — مع `monthly_price`، `commission_pct`، `max_active_jobs`، `features jsonb`.
  - Seed: ثلاث باقات افتراضية (مجاني 20%، موثّق 199ر.س 15%، مميّز 499ر.س 10%).
  - `provider_subscriptions` — اشتراكات نشطة لكل مزوّد.
  - `commissions` — حساب لكل طلب مكتمل.
  - `ad_creatives` و `ad_placements` و `ad_impressions` — نظام إعلانات قابل للقياس.
  - `invoices` و `payments` — تتبّع الفوترة مع integration متعدّد المزوّدين.
  - RLS صارم: قراءة الباقات للجميع، الكتابة للأدمن فقط؛ الاشتراكات والعمولات والفواتير للمالك أو الأدمن.

### كود التطبيق

- [x] `/pricing` — صفحة باقات مع شارة "الأكثر طلباً" وعرض الميزات والعمولة.
- [x] ترجمات `pricing` كاملة في الخمس لغات.

## ما يحتاج تكاملاً حقيقياً

- [ ] Edge Function `payments-create-charge` لـ Tap/Moyasar/HyperPay (اختيار يُحسم).
- [ ] Webhook `payments-webhook` مع تحقّق HMAC وقفل idempotency.
- [ ] إصدار فواتير PDF (jsPDF أو @react-pdf على Edge).
- [ ] Page لإدارة الاشتراك في `/dashboard/subscription` لـ provider.
- [ ] تنفيذ "monthly top providers" cron.

## بوابة المرحلة 9

| الفحص | النتيجة |
|---|---|
| typecheck | ✅ |
| build | ✅ |
| صفحة الأسعار تعرض 3 باقات | ✅ |
| الترجمات تظهر في الخمس لغات | ✅ |
| سياسات RLS تمنع الكتابة من غير الأدمن | ✅ |
| نظام إعلانات قابل للقياس (impressions + clicks) | ✅ |
