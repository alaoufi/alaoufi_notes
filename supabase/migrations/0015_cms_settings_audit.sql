-- Syanah · 0015 · Editable translations, message templates, settings, api_secrets, audit_log.

begin;

-- translations: key → locale → value (overrides bundled messages/*.json)

create table if not exists public.translations (
  id uuid primary key default gen_random_uuid(),
  key text not null,
  locale text not null check (locale in ('ar','ur','en','hi','bn')),
  value text not null,
  updated_by uuid references public.profiles(user_id) on delete set null,
  updated_at timestamptz not null default now(),
  unique (key, locale)
);

create index if not exists translations_key_idx on public.translations (key);

-- message_templates: SMS/WhatsApp/Email content with placeholders

create table if not exists public.message_templates (
  id uuid primary key default gen_random_uuid(),
  slug text not null,                                         -- e.g. 'order.accepted'
  channel text not null check (channel in ('sms','whatsapp','email','push')),
  locale text not null check (locale in ('ar','ur','en','hi','bn')),
  subject text,
  body text not null,
  variables jsonb,                                           -- documentation of supported {vars}
  is_active boolean not null default true,
  updated_by uuid references public.profiles(user_id) on delete set null,
  updated_at timestamptz not null default now(),
  unique (slug, channel, locale)
);

create index if not exists message_templates_slug_channel_idx
  on public.message_templates (slug, channel, locale, is_active);

-- settings: arbitrary key/value config (feature flags, theme default, ...)

create table if not exists public.settings (
  key text primary key,
  value jsonb not null,
  description text,
  updated_by uuid references public.profiles(user_id) on delete set null,
  updated_at timestamptz not null default now()
);

insert into public.settings (key, value, description) values
  ('app.default_locale', '"ar"', 'Default locale for new users'),
  ('app.default_theme', '"soft-blue"', 'Default theme for new users'),
  ('app.enabled_locales', '["ar","ur","en","hi","bn"]', 'Locales available in UI'),
  ('orders.cancel_window_minutes', '5', 'Minutes after creation that requester can cancel free'),
  ('chat.media.image_max_bytes', '8388608', '8 MB image cap for chat'),
  ('chat.media.voice_max_ms', '300000', '5 min voice cap'),
  ('disputes.window_hours', '72', 'Hours after completion to open a dispute')
on conflict (key) do nothing;

-- api_secrets: encrypted at rest by application layer (libsodium) before storing.

create table if not exists public.api_secrets (
  key text primary key,
  value_encrypted text not null,
  description text,
  rotated_at timestamptz,
  created_at timestamptz not null default now()
);

-- audit_log: every sensitive change

create table if not exists public.audit_log (
  id bigserial primary key,
  actor_id uuid references public.profiles(user_id) on delete set null,
  action text not null,
  target_table text,
  target_id text,
  before jsonb,
  after jsonb,
  ip text,
  user_agent text,
  created_at timestamptz not null default now()
);

create index if not exists audit_log_actor_idx on public.audit_log (actor_id, created_at desc);
create index if not exists audit_log_target_idx on public.audit_log (target_table, target_id, created_at desc);

-- RLS

alter table public.translations enable row level security;
alter table public.message_templates enable row level security;
alter table public.settings enable row level security;
alter table public.api_secrets enable row level security;
alter table public.audit_log enable row level security;

drop policy if exists translations_read_all on public.translations;
create policy translations_read_all
  on public.translations for select
  to anon, authenticated
  using (true);

drop policy if exists translations_write_admin on public.translations;
create policy translations_write_admin
  on public.translations for all
  to authenticated
  using (public.user_is_admin(auth.uid()))
  with check (public.user_is_admin(auth.uid()));

drop policy if exists message_templates_read_admin on public.message_templates;
create policy message_templates_read_admin
  on public.message_templates for select
  to authenticated
  using (public.user_is_admin(auth.uid()));

drop policy if exists message_templates_write_super on public.message_templates;
create policy message_templates_write_super
  on public.message_templates for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

drop policy if exists settings_read_all on public.settings;
create policy settings_read_all
  on public.settings for select
  to anon, authenticated
  using (true);

drop policy if exists settings_write_super on public.settings;
create policy settings_write_super
  on public.settings for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

-- api_secrets: read/write only via service_role; no public policy granted.
-- (RLS enabled with no policies = deny all to authenticated/anon)

drop policy if exists audit_log_select_admin on public.audit_log;
create policy audit_log_select_admin
  on public.audit_log for select
  to authenticated
  using (public.user_is_admin(auth.uid()));

-- audit log is append-only via service_role; no insert/update/delete granted publicly.

commit;
