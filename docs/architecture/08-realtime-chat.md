# 08 — الزمن الحقيقي والدردشة

## نظرة عامة

نظام الدردشة هو محور التواصل في صيانة. كل طلب يولّد محادثة مستقلّة معزولة. التصميم يجب أن يدعم:

- نص + صورة + ملف + صوت + موقع + رسائل نظام.
- إيصالات تسليم وقراءة + مؤشّر كتابة.
- بحث/تمرير سريع داخل المحادثة.
- أرشفة تلقائية عند انتهاء الطلب — قراءة فقط، تُستخدم كأدلّة نزاعات.
- زمن استجابة < 500 ms (P95) للرسائل النصية.

## التقنية

- **النقل:** Supabase Realtime على قنوات Postgres Changes + Broadcast.
- **التخزين:** جدول `messages` لتاريخ الرسائل + جدول `message_reads` لإيصالات القراءة + Supabase Storage لمرفقات الوسائط.
- **العميل:** `@supabase/supabase-js` على الويب، حزمة `supabase_flutter` على الموبايل.
- **الإشعارات Push:** عند إرسال رسالة، Edge Function `chat-fanout` ترسل push للأطراف غير المتصلة.

## القنوات

| القناة | المشاركون | نوع البث |
|---|---|---|
| `conversation:<id>` | طرفا الطلب + الإدارة (read-only للنزاع) | INSERT/UPDATE/DELETE على `messages` |
| `presence:conversation:<id>` | الطرفان | حضور (online/offline) + typing |
| `tracking:<order_id>` | طالب الخدمة فقط (المزوّد يبث) | broadcast لرسائل location_ping |
| `notifications:user:<id>` | المستخدم | إشعارات in-app |

### الاشتراك (مثال ويب)

```ts
const channel = supabase
  .channel(`conversation:${conversationId}`)
  .on('postgres_changes',
    { event: 'INSERT', schema: 'public', table: 'messages',
      filter: `conversation_id=eq.${conversationId}` },
    (payload) => addMessage(payload.new))
  .on('postgres_changes',
    { event: 'UPDATE', schema: 'public', table: 'messages',
      filter: `conversation_id=eq.${conversationId}` },
    (payload) => updateMessage(payload.new))
  .subscribe();
```

## دورة حياة المحادثة

```
طلب يُنشأ
   └── trigger DB يُنشئ conversations (one-to-one مع orders)
       └── الطرفان يستطيعان فتح المحادثة فوراً (حتى قبل قبول الطلب — لطلب تفاصيل)
الطلب يُكتمل (status='completed')
   └── Edge Function `chat-archive` يُشغَّل بعد 24 ساعة:
       ├── يُعدّل conversations.is_archived = true
       ├── يحظر INSERT/UPDATE/DELETE عبر سياسة RLS
       └── يُولّد ملف PDF (للأدلة) ويُخزّنه في bucket `dispute-evidence`
نزاع يُفتَح
   └── المحادثة تظل قابلة للقراءة من الإدارة طوال فترة النزاع
   └── الأدلة المُولّدة تُنسخ إلى مرفقات النزاع
```

سياسة RLS بعد الأرشفة:

```sql
create policy messages_no_write_after_archive on messages
  for insert to authenticated
  with check (
    not exists (
      select 1 from conversations where id = messages.conversation_id and is_archived = true
    )
  );
```

## أنواع الرسائل

| Type | جسم | حقول إضافية |
|---|---|---|
| `text` | `body` | — |
| `image` | — | `media_path`, `media_mime`, optional thumbnail in same bucket |
| `file` | — | `media_path`, `media_mime`, `media_size_bytes` |
| `voice` | — | `media_path`, `media_duration_ms`, `waveform jsonb` (peaks مُسبقة الحساب) |
| `location` | optional caption in `body` | `latitude`, `longitude` |
| `system` | localized key in `body` (مثل `system.order_accepted`) | `payload jsonb` |

### معالجة الوسائط

- العميل يضغط الصور إلى ≤ 1600px قبل الرفع.
- الصوت يُسجَّل بـ `opus`/`m4a` 32kbps mono.
- الـ waveform (16 نقطة قمم) تُحسب على العميل وتُحفظ في `messages.waveform`.
- كل media_path في bucket خاص (`chat-media`) لا يُقرأ إلا عبر signed URL محدود (10 دقائق) يُولَّد من الخادم.

## الحضور و typing

عبر Supabase Realtime Presence:

```ts
channel.track({ user_id, typing: false, last_seen_at: Date.now() });
// عند الكتابة:
channel.track({ ..., typing: true });
// مع debounce 2s ثم إعادة typing=false
```

العميل يستهلك `channel.presenceState()` لعرض النقاط الزرقاء وكلمة "يكتب الآن...".

## إيصالات القراءة

جدول `message_reads`:

```sql
create table message_reads (
  message_id uuid not null references messages(id) on delete cascade,
  reader_id uuid not null references profiles(user_id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (message_id, reader_id)
);
```

العميل يُرسل دفعة `upsert` كل مرّة يصبح فيها مرئيّاً ضمن viewport. خادم يُحدّث ثم يبث UPDATE للقناة لتُظهر العلامتين الزرقاوين عند المرسل.

## الموقع المباشر (Live Location)

أثناء الطلب النشط `status in ('en_route','in_progress')`:

- المزوّد ينشر نبضة كل 5 ثوانٍ (مع تجميع إذا لم يتحرّك > 10 متر):
  ```ts
  channel.send({ type: 'broadcast', event: 'ping',
                 payload: { lat, lng, heading, speed, ts } });
  ```
- طالب الخدمة يستمع ويُحدّث الخريطة.
- لا تُحفظ كل نبضة في DB — فقط آخر موقع يُكتب في `providers.current_location` كل 30 ثانية لاستعلامات "المزوّدون القريبون".

## إشعارات الـ Push عند الرسائل

Edge Function `chat-fanout` يُستدعى من trigger AFTER INSERT على `messages`:

```sql
create trigger messages_after_insert
  after insert on messages
  for each row execute function http_call_edge('chat-fanout', new);
```

الـ function:
1. يجلب المستلمين (طرف المحادثة الآخر فقط).
2. يفحص presence: هل مرتبط بالقناة الآن؟ إذا نعم — لا push.
3. إذا لا — يُرسل push عبر FCM/APNs/HMS مع `notification_deliveries` log.

## التحديات والحلول

| التحدي | الحل |
|---|---|
| فيضان رسائل (spam) | حد 30 رسالة/دقيقة لكل مستخدم في كل محادثة (تُفرَض في Edge Function) |
| رسائل ضخمة | تحقّق `length(body) <= 4000` في trigger DB |
| اتصال متقطّع | العميل يُخزّن الرسائل المعلّقة في localStorage مع `client_id` للـ idempotency |
| ترتيب الرسائل | المعتمَد: `created_at` من الخادم؛ العميل يُعيد الترتيب عند الاستلام |
| فقدان رسائل أثناء offline | عند العودة، العميل يُجلب `where conversation_id=... and created_at > last_seen` |
| فاتورة Realtime | تجميع نبضات الموقع، تحديد عدد القنوات المفتوحة لكل مستخدم (≤ 10) |

## مقاييس قابلية التوسع (مرجعية)

- محادثات نشطة متوقّعة في الذروة (السنة الأولى): 5,000 متزامنة.
- رسائل/ثانية في الذروة: 500/sec.
- Supabase Realtime على الخطة المدفوعة يدعم حتى 10,000 اتصال متزامن — كافٍ مع هامش 2×.
- خطة الترقية: عند بلوغ 70% من الحد، الانتقال إلى Realtime Dedicated أو إضافة layer LiveKit/Ably.

## التدقيق والامتثال

- كل رسالة لها `created_at` غير قابل للتعديل.
- التعديل يُسجَّل في `messages.edited_at` بحدّ أقصى 5 دقائق من الإرسال.
- الحذف الناعم فقط (`deleted_at`)؛ المحتوى يبقى للأدلة لكن لا يُعرض للمستخدم.
- النزاعات تُجمّد المحادثة من التعديل تلقائياً.
