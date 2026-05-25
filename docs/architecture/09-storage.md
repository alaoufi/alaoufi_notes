# 09 — التخزين

Supabase Storage مدعوم بـ S3. التصميم يفصل المحتوى حسب الحساسية ودورة الحياة.

## الحاويات (Buckets)

| Bucket | عام/خاص | الاستخدام | TTL |
|---|---|---|---|
| `avatars` | عام (CDN) | صور الملفات الشخصية | لا يُحذف؛ نسخة قديمة تُستبدل |
| `category-icons` | عام | أيقونات الفئات والثيمات | إصدارات بـ hash |
| `marketing-media` | عام | صور التسويق والإعلانات | يُديره الأدمن |
| `chat-media` | خاص | صور/ملفات/صوت من الدردشة | يبقى إلى أن تُؤرشف المحادثة + 90 يوماً |
| `dispute-evidence` | خاص (للأدمن فقط) | أدلة النزاعات (PDF من المحادثة، نسخ من chat-media) | يبقى 7 سنوات (متطلب امتثال) |
| `provider-documents` | خاص | هوية المزوّد، السجل التجاري، تأمين | يبقى طوال نشاط المزوّد |
| `order-attachments` | خاص | صور يرفعها الطالب عند إنشاء الطلب | يبقى طوال عمر الطلب + 1 سنة |
| `invoices` | خاص | فواتير PDF للمزوّدين والإدارة | يبقى 7 سنوات |
| `exports` | خاص | تقارير CSV/Excel من الإدارة | TTL 7 أيام |

## سياسات الوصول

كل Bucket خاص محكوم بـ RLS-like policy:

```sql
-- مثال chat-media
create policy "chat_media_read_participants"
on storage.objects for select
to authenticated
using (
  bucket_id = 'chat-media'
  and exists (
    select 1 from messages m
    join conversations c on c.id = m.conversation_id
    join orders o on o.id = c.order_id
    where m.media_path = storage.objects.name
      and (o.requester_id = auth.uid() or o.provider_id = auth.uid()
           or exists (select 1 from user_roles where user_id = auth.uid()
                       and role in ('super_admin','section_admin')))
  )
);

create policy "chat_media_insert_participants"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'chat-media'
  -- مسار يُجبر على نمط: <conversation_id>/<user_id>/<uuid>.<ext>
  and split_part(name, '/', 2) = auth.uid()::text
  and exists (
    select 1 from conversations c
    join orders o on o.id = c.order_id
    where c.id::text = split_part(name, '/', 1)
      and (o.requester_id = auth.uid() or o.provider_id = auth.uid())
      and c.is_archived = false
  )
);
```

## مفاتيح المسارات (Path Conventions)

| Bucket | النمط |
|---|---|
| `avatars` | `<user_id>.webp` |
| `chat-media` | `<conversation_id>/<sender_id>/<uuid>.<ext>` |
| `provider-documents` | `<provider_id>/<doc_type>/<uuid>.<ext>` (doc_type ∈ id, cr, insurance) |
| `order-attachments` | `<order_id>/<uuid>.<ext>` |
| `dispute-evidence` | `<dispute_id>/<artifact_type>/<uuid>.<ext>` |
| `invoices` | `<year>/<month>/<invoice_id>.pdf` |
| `exports` | `<user_id>/<timestamp>-<slug>.csv` |

## Signed URLs

الحاويات الخاصة لا تُسلّم URL مباشرة. الخادم يُولّد signed URL بصلاحية محدودة:

| المحتوى | المدة |
|---|---|
| chat-media (عرض) | 10 دقائق |
| provider-documents (إدارة) | 5 دقائق |
| invoices للمستخدم | 60 دقيقة |
| exports | 7 أيام (للتنزيل المتعدد) |

العميل لا يُولّد signed URL — كل URL يأتي عبر Edge Function `storage-sign-url` التي تفحص الصلاحيات.

## الرفع

- العميل يطلب `storage-upload-init` من الخادم → يُرجع URL رفع موقّع (Resumable Upload).
- الحد الأقصى لحجم الملف:
  - صورة دردشة: 8 MB
  - ملف دردشة: 25 MB
  - صوت دردشة: 5 MB (يكفي ≈ 5 دقائق opus)
  - وثيقة مزوّد: 10 MB
  - مرفق طلب: 8 MB / حتى 5 ملفات لكل طلب
- التحقّق على الخادم بعد الرفع:
  - النوع MIME ضد قائمة بيضاء
  - فحص حجم فعلي
  - فحص antivirus (Cloudflare R2 + ClamAV على worker — مرحلة 12)

## الـ Lifecycle

`pg_cron` يشغّل يومياً وظيفة Edge تنفّذ:

- حذف `exports` أقدم من 7 أيام.
- حذف `chat-media` لمحادثات مؤرشفة منذ > 90 يوماً ولا نزاع مفتوح.
- حذف soft-deleted avatars بعد 30 يوماً.
- نسخ النسخ الاحتياطية إلى S3 منفصل (مزود ثانٍ) أسبوعياً — للحماية من فقد catastrophic.

## التشفير

- جميع الـ buckets تستخدم تشفير AES-256 في الراحة (افتراضي Supabase).
- مستندات المزوّدين (الهوية، السجل) تُشفَّر بمفتاح إضافي على مستوى التطبيق قبل الرفع — لا يُفك إلا داخل Edge Function للإدارة.
- النقل: HTTPS فقط، TLS 1.2+.

## النسخ الاحتياطي

- Supabase يأخذ snapshots يومية لـ DB.
- التخزين: نسخ متعدد المناطق على S3.
- اختبار استعادة نصف سنوي موثَّق في `infra/runbooks/restore-storage.md` (يُكتب في المرحلة 11).

## CDN

- الحاويات العامة تُسلَّم عبر Supabase CDN + Cloudflare أمامها.
- التحويل (resize/format) عبر Supabase Image Transformations أو `next/image` على الويب.
- ETag و Cache-Control محدّدة بدقة (افتراض: `public, max-age=31536000, immutable` للأصول المُنسَّقة بـ hash).

## مراقبة الاستخدام

- لوحة Grafana تعرض حجم تخزين/Bucket وتنبّه عند تجاوز 70% من الخطة.
- تقرير شهري يُرسل تلقائياً للإدارة بأكبر 10 مزوّدين/مستخدمين استهلاكاً.
