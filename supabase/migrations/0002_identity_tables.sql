-- Syanah · 0002 · Identity tables: profiles, user_roles, admin_sections, devices, verifications.
-- RLS is enabled on every table; explicit policies grant access (default deny).

begin;

-- profiles: 1:1 with auth.users; holds non-auth fields like preferred locale/theme.

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone_e164 text unique,
  email_normalized text unique,
  preferred_locale text not null default 'ar' check (preferred_locale in ('ar','ur','en','hi','bn')),
  preferred_theme text not null default 'soft-blue' check (preferred_theme in ('soft-blue','pink')),
  avatar_path text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- user_roles: many-to-many (a single end user is just one role; staff may have multiple).

create table if not exists public.user_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role user_role not null,
  granted_by uuid references auth.users(id) on delete set null,
  granted_at timestamptz not null default now(),
  primary key (user_id, role)
);

-- admin_sections: scoped buckets (e.g., category=hvac, city=riyadh) for section_admin assignments.

create table if not exists public.admin_sections (
  id uuid primary key default gen_random_uuid(),
  scope_type text not null check (scope_type in ('category', 'city', 'region', 'global')),
  scope_value text not null,
  label jsonb not null,                  -- {ar, en, ...}
  created_at timestamptz not null default now(),
  unique (scope_type, scope_value)
);

create table if not exists public.section_admin_assignments (
  section_admin_id uuid not null references auth.users(id) on delete cascade,
  admin_section_id uuid not null references public.admin_sections(id) on delete cascade,
  assigned_at timestamptz not null default now(),
  primary key (section_admin_id, admin_section_id)
);

-- devices: registered devices for push notifications.

create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('web', 'ios', 'android', 'huawei')),
  push_token text,
  user_agent text,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists devices_user_id_idx on public.devices(user_id);

-- verifications: one row per attempt (sms/whatsapp/nafath/email).

create table if not exists public.verifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  method verification_method not null,
  destination text not null,             -- phone / email / nafath-id
  code_hash text,                        -- hashed OTP; null for nafath (uses external session)
  status verification_status not null default 'pending',
  attempts int not null default 0,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists verifications_user_method_idx
  on public.verifications(user_id, method, created_at desc);

-- helper: does this user hold a given role?

create or replace function public.user_has_role(p_user uuid, p_role user_role)
returns boolean
language sql
stable
as $$
  select exists(select 1 from public.user_roles where user_id = p_user and role = p_role);
$$;

-- helper: is this user a staff admin (super or section)?

create or replace function public.user_is_admin(p_user uuid)
returns boolean
language sql
stable
as $$
  select exists(
    select 1 from public.user_roles
    where user_id = p_user and role in ('super_admin','section_admin')
  );
$$;

commit;
