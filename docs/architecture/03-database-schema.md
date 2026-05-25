# 03 — مخطط قاعدة البيانات

Postgres 16 على Supabase. كل الجداول تُفعِّل **Row Level Security (RLS)**؛ السياسات مذكورة في المستندين 05 و 10. هذا المستند يحدّد **شكل** البيانات.

> هذا مخطط v1 الذي يخدم المراحل من 3 إلى 9. الترحيلات تُضاف تدريجياً لكل مرحلة. الترحيل `0001_init_schema.sql` يُكتب عند بداية المرحلة 3.

## الاتفاقيات

- المفاتيح الأساسية: `uuid` افتراضي `gen_random_uuid()`.
- الطوابع الزمنية: `created_at timestamptz not null default now()`, `updated_at timestamptz not null default now()` (مع trigger).
- الحذف الناعم: `deleted_at timestamptz` حيث ينطبق. الحذف الصلب فقط للسبام / الامتثال.
- المال: `numeric(12,2)`، العملة تُخزّن بمعيار ISO 4217 (`SAR`).
- الإحداثيات: PostGIS `geography(Point, 4326)` (تفعيل امتداد `postgis`).
- الحقول النصية متعدّدة اللغات تستخدم `jsonb` مفتاحه الـ locale: `{"ar": "...", "en": "..."}`.
- Enums: أنواع Postgres `enum` حيث المجموعة مغلقة ونادراً ما تتغيّر.

## الامتدادات المُفعَّلة

```sql
create extension if not exists "pgcrypto";
create extension if not exists "pg_trgm";
create extension if not exists "postgis";
create extension if not exists "pg_cron";
```

## أنواع Enum

```sql
create type user_role        as enum ('super_admin','section_admin','provider','requester');
create type verification_method as enum ('nafath','sms','whatsapp','email');
create type order_status     as enum ('draft','pending','accepted','rejected','en_route','in_progress','completed','cancelled','disputed');
create type dispute_status   as enum ('open','under_review','resolved_requester','resolved_provider','dismissed');
create type message_type     as enum ('text','image','file','voice','location','system');
create type subscription_tier as enum ('free','trusted','featured');
create type ad_placement     as enum ('home_top','category_top','search_top','category_inline');
```

## الجداول (مجموعات منطقية)

### 1. الهوية والأدوار

```
auth.users                  -- مُدار بواسطة Supabase
profiles                    -- 1:1 مع auth.users؛ بيانات أساسية + اللغة + الثيم
user_roles                  -- user_id × role (many-to-many للموظفين؛ مفرد للمستخدمين النهائيين)
admin_sections              -- نطاقات مُسنَدة لـ section_admin (مثل "تكييف"، "الرياض")
section_admin_assignments   -- section_admin_id × admin_section_id
verifications               -- صف لكل محاولة تحقّق
devices                     -- الأجهزة المسجَّلة للإشعارات (fcm/apns/hms token)
```

أعمدة رئيسية:

```sql
create table profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone_e164 text unique,
  email_normalized text unique,
  preferred_locale text not null default 'ar' check (preferred_locale in ('ar','ur','en','hi','bn')),
  preferred_theme text not null default 'soft_blue' check (preferred_theme in ('soft_blue','pink')),
  avatar_path text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table user_roles (
  user_id uuid references auth.users(id) on delete cascade,
  role user_role not null,
  granted_by uuid references auth.users(id),
  granted_at timestamptz not null default now(),
  primary key (user_id, role)
);
```

### 2. ملف المزوّد

```
providers                   -- بيانات مزوّد موسّعة
provider_categories         -- many-to-many مع الفئات
provider_coverage_areas     -- polygons أو مدينة + نصف قطر
provider_documents          -- هوية، سجل تجاري، تأمين — تُخزّن في حاوية خاصة
provider_availability       -- جدول أسبوعي + استثناءات
provider_stats              -- materialized view (تقييم، نسبة الإنجاز، زمن الاستجابة)
```

```sql
create table providers (
  user_id uuid primary key references profiles(user_id) on delete cascade,
  display_name jsonb not null,          -- {ar, en, ...}
  bio jsonb,
  business_type text not null default 'individual', -- individual | company
  cr_number text,
  vat_number text,
  hourly_rate numeric(12,2),
  currency text not null default 'SAR',
  subscription_tier subscription_tier not null default 'free',
  subscription_expires_at timestamptz,
  is_verified boolean not null default false,
  is_active boolean not null default true,
  current_location geography(Point, 4326), -- يُحدَّث فقط أثناء طلبات نشطة
  current_location_updated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index providers_active_verified_idx on providers (is_active, is_verified);
create index providers_location_gix on providers using gist (current_location);
```

### 3. الكتالوج (الفئات، الخدمات، المواقع)

```
categories                  -- المستوى الأعلى (تكييف، سباكة، ...)
subcategories               -- أبناء الفئات
services                    -- خدمة قابلة للحجز ضمن فئة فرعية
cities
districts
```

```sql
create table categories (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name jsonb not null,           -- {ar, en, ...}
  description jsonb,
  icon_path text,
  display_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table subcategories (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references categories(id) on delete cascade,
  slug text not null,
  name jsonb not null,
  display_order int not null default 0,
  is_active boolean not null default true,
  unique (category_id, slug)
);

create table services (
  id uuid primary key default gen_random_uuid(),
  subcategory_id uuid not null references subcategories(id) on delete cascade,
  slug text not null,
  name jsonb not null,
  description jsonb,
  base_price numeric(12,2),
  price_unit text default 'visit',     -- visit | hour | fixed
  is_active boolean not null default true,
  unique (subcategory_id, slug)
);
```

### 4. الطلبات

```
orders
order_status_history
order_items                 -- بنود إذا كان الطلب يضم خدمات متعددة
order_attachments           -- صور يُضيفها الطالب عند إنشاء الطلب
```

```sql
create table orders (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,           -- مختصر صديق للبشر (مثل SY-2026-000123)
  requester_id uuid not null references profiles(user_id) on delete restrict,
  provider_id uuid references profiles(user_id) on delete restrict,
  category_id uuid not null references categories(id),
  subcategory_id uuid references subcategories(id),
  status order_status not null default 'pending',
  scheduled_at timestamptz,            -- null = فوري
  address_label text not null,
  address_details text,
  location geography(Point, 4326) not null,
  city_id uuid references cities(id),
  district_id uuid references districts(id),
  estimated_total numeric(12,2),
  final_total numeric(12,2),
  currency text not null default 'SAR',
  cancellation_reason text,
  cancelled_by uuid references profiles(user_id),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index orders_requester_status_idx on orders (requester_id, status);
create index orders_provider_status_idx  on orders (provider_id, status);
create index orders_location_gix         on orders using gist (location);

create table order_status_history (
  id bigserial primary key,
  order_id uuid not null references orders(id) on delete cascade,
  from_status order_status,
  to_status order_status not null,
  changed_by uuid references profiles(user_id),
  reason text,
  created_at timestamptz not null default now()
);
```

آلة الحالات (تُفرَض في server actions و trigger من نوع `before update`):

```
pending → accepted | rejected | cancelled
accepted → en_route | cancelled
en_route → in_progress | cancelled
in_progress → completed | disputed
completed → disputed   (داخل نافذة فتح النزاع)
disputed → completed | cancelled (بعد الحلّ)
```

### 5. الدردشة و Realtime

```
conversations               -- محادثة واحدة لكل طلب
messages
message_reads               -- إيصالات قراءة لكل مستخدم
typing_indicators           -- عابرة، تُنظَّف عبر cron
location_pings              -- موقع المزوّد المباشر أثناء طلب نشط
```

```sql
create table conversations (
  id uuid primary key default gen_random_uuid(),
  order_id uuid unique not null references orders(id) on delete cascade,
  is_archived boolean not null default false,
  archived_at timestamptz,
  created_at timestamptz not null default now()
);

create table messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id uuid not null references profiles(user_id),
  type message_type not null,
  body text,                       -- نص عادي أو null للوسائط
  media_path text,                 -- مسار في حاوية خاصة
  media_mime text,
  media_duration_ms int,           -- للصوت
  latitude double precision,       -- لنوع location
  longitude double precision,
  reply_to_message_id uuid references messages(id),
  edited_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

create index messages_conversation_created_idx on messages (conversation_id, created_at desc);
```

### 6. التقييمات والمراجعات

```
ratings                     -- صف واحد لكل (order, rater_role)
reviews
review_translations         -- ترجمات مُخزّنة مؤقتاً
```

```sql
create table ratings (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  rater_id uuid not null references profiles(user_id),
  ratee_id uuid not null references profiles(user_id),
  score int not null check (score between 1 and 5),
  comment text,
  is_visible boolean not null default true,   -- يُخفى أثناء النزاع
  created_at timestamptz not null default now(),
  unique (order_id, rater_id)
);
```

### 7. النزاعات

```
disputes
dispute_evidence            -- مقتطفات دردشة، صور، صوت
dispute_actions             -- تدقيق إجراءات الإدارة
```

```sql
create table disputes (
  id uuid primary key default gen_random_uuid(),
  order_id uuid unique not null references orders(id) on delete cascade,
  opened_by uuid not null references profiles(user_id),
  reason text not null,
  description text,
  status dispute_status not null default 'open',
  assigned_admin_id uuid references profiles(user_id),
  resolved_at timestamptz,
  resolution_note text,
  created_at timestamptz not null default now()
);
```

### 8. الاشتراكات والإعلانات والعمولات

```
subscription_packages       -- كتالوج باقات المزوّدين
provider_subscriptions      -- الاشتراك الفعّال لكل مزوّد
commissions                 -- عمولة المنصة لكل طلب مكتمل
ad_creatives
ad_placements_log           -- مشاهدات، نقرات
invoices                    -- الفوترة
payments
```

### 9. الإشعارات

```
notifications               -- تغذية داخل التطبيق
notification_deliveries     -- سجل تسليم لكل قناة (push, sms, email)
notification_preferences    -- لكل مستخدم، لكل قناة، لكل فئة
```

### 10. CMS والإعدادات

```
translations                -- نصوص واجهة قابلة للتعديل: (key, locale) → value
message_templates           -- قوالب SMS / WhatsApp / بريد مع متغيرات
settings                    -- إعدادات key/value (افتراضيات الثيم، feature flags)
api_secrets                 -- مشفّرة في الراحة، تُقرأ فقط من Edge Functions
audit_log                   -- كل تغيير في الإعدادات/الأسرار
```

### 11. الجغرافيا

```
cities                      -- name jsonb, polygon
districts                   -- polygon
```

## استراتيجية الفهرسة (استعلامات عالية الازدحام)

- `messages (conversation_id, created_at desc)` — للتمرير في الدردشة.
- `orders (provider_id, status)` و `orders (requester_id, status)` — للبوابات.
- GIST على `orders.location` و `providers.current_location` — لاستعلامات "الأقرب".
- فهرس GIN بـ `pg_trgm` على `services.name->>'ar'` و `'en'` للبحث.
- فهرس جزئي `where status in ('pending','accepted','en_route','in_progress')` للوحة الطلبات النشطة.

## Materialized views

- `provider_stats` — تُحدَّث كل 5 دقائق عبر `pg_cron`. يحوي متوسط التقييم، نسبة الإنجاز (آخر 30/90 يوم)، زمن الاستجابة، إجمالي الطلبات.
- `monthly_top_providers` — تُحدَّث يومياً.

## تغطية RLS

كل جدول مذكور أعلاه يُفعِّل RLS. السياسات معرَّفة في المستند 05 (الأدوار والصلاحيات) و 10 (الأمان). الافتراضي هو **رفض الكل**؛ الوصول يُمنح صراحةً لكل جدول لكل دور.

## خطة الترحيلات

- المرحلة 3 تُدخل: profiles، user_roles، providers (أساسي)، verifications، devices.
- المرحلة 4 تُدخل: categories، subcategories، services، cities، districts، provider_coverage_areas، provider_categories.
- المرحلة 5 تُدخل: location_pings؛ تُضيف `current_location` لـ `providers`.
- المرحلة 6 تُدخل: conversations، messages، message_reads، typing_indicators.
- المرحلة 7 تُدخل: orders، order_status_history، order_items، order_attachments، notifications.
- المرحلة 8 تُدخل: ratings، reviews، disputes، dispute_evidence، dispute_actions.
- المرحلة 9 تُدخل: subscription_packages، provider_subscriptions، commissions، ads، invoices، payments.
- المرحلة 10 تُدخل: translations، message_templates، settings، api_secrets، audit_log.

ملفات الترحيل غير قابلة للتغيير بعد دمجها في `main`. أي تغييرات لاحقة هي ترحيلات إضافية أحادية الاتجاه (forward-only).
