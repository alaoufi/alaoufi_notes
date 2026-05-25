# المرحلة 6 — نظام الدردشة المتقدّم — مراجعة وتوقيع

## المخرجات

### قاعدة البيانات

- [x] `0009_chat_tables.sql`:
  - enum `message_type` (text, image, file, voice, location, system).
  - `conversations` (1:1 مع orders، FK ينضمّ في 0011 عند توفّر orders).
  - `messages` مع check constraints (نص ≤ 4000 حرف، وسائط حسب النوع).
  - `message_reads` لإيصالات القراءة لكل مستخدم.
  - فهارس على `(conversation_id, created_at desc)` للتمرير و `(sender_id, created_at desc)` للتحليل.
  - RLS مفعّل، السياسات الكاملة (طرفا الطلب) تُربط بعد جدول `orders` في 0011.

### كود التطبيق

- [x] `features/chat/types.ts` — أنواع `ChatMessage` و `ChatParticipant`.
- [x] `features/chat/components/message-bubble.tsx` — فقاعة رسالة تدعم 6 أنواع، RTL-aware.
- [x] `features/chat/components/chat-thread.tsx` — محادثة كاملة قابلة للتمرير، نموذج إرسال، أزرار إرفاق/موقع/صوت (مرئية، التنفيذ في المرحلة 7 مع Supabase).
- [x] صفحة `/[locale]/chat-demo` للعرض البصري.
- [x] ترجمات `chatDemo` في الخمس لغات.

## مسائل خاصة بـ Phase 7

- ربط `useChannel("conversation:<id>")` لاستهلاك أحداث postgres_changes.
- ربط `presence` لمؤشّر الكتابة وحالة الاتصال.
- Edge Function `chat-fanout` لإرسال push notifications.
- رفع الوسائط إلى bucket `chat-media` مع signed URLs.

## بوابة المرحلة 6

| الفحص | النتيجة |
|---|---|
| typecheck | ✅ |
| build | ✅ |
| الفقاعات تعرض في RTL وLTR | ✅ |
| المحادثة تتمرّر للأسفل تلقائياً عند رسالة جديدة | ✅ |
| الإرسال يعمل (محلياً) | ✅ |
| المحادثة المؤرشفة للقراءة فقط | ✅ |
| فهارس DB موجودة | ✅ |
| Check constraints على أنواع الرسائل | ✅ |
