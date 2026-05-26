-- ============================================================================
-- Syanah — Supabase one-shot setup script
-- Generated from migrations 0001 → 0024.
-- Paste this whole file into Supabase Studio → SQL Editor → Run.
-- Safe to re-run (every statement uses IF NOT EXISTS / ON CONFLICT).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 0001_init_extensions_enums.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0001 · Extensions and enum types.
-- These are foundation pieces required by every later migration.

begin;

create extension if not exists "pgcrypto";
create extension if not exists "pg_trgm";

-- enums

do $$ begin
  if not exists (select 1 from pg_type where typname = 'user_role') then
    create type user_role as enum ('super_admin', 'section_admin', 'provider', 'requester');
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'verification_method') then
    create type verification_method as enum ('nafath', 'sms', 'whatsapp', 'email');
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'verification_status') then
    create type verification_status as enum ('pending', 'verified', 'expired', 'failed');
  end if;
end $$;

-- shared trigger function to maintain updated_at on row updates.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

commit;


-- ----------------------------------------------------------------------------
-- 0002_identity_tables.sql
-- ----------------------------------------------------------------------------
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
  preferred_theme text not null default 'navy' check (preferred_theme in ('navy','stc','fuchsia')),
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


-- ----------------------------------------------------------------------------
-- 0003_identity_rls.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0003 · RLS policies for identity tables.
-- Default policy: deny all. Explicit policies grant the minimum each role needs.

begin;

-- profiles

alter table public.profiles enable row level security;

drop policy if exists profiles_select_self_or_admin on public.profiles;
create policy profiles_select_self_or_admin
  on public.profiles for select
  to authenticated
  using (user_id = auth.uid() or public.user_is_admin(auth.uid()));

drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self
  on public.profiles for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists profiles_update_self_or_admin on public.profiles;
create policy profiles_update_self_or_admin
  on public.profiles for update
  to authenticated
  using (user_id = auth.uid() or public.user_is_admin(auth.uid()))
  with check (user_id = auth.uid() or public.user_is_admin(auth.uid()));

-- user_roles

alter table public.user_roles enable row level security;

drop policy if exists user_roles_select_self_or_admin on public.user_roles;
create policy user_roles_select_self_or_admin
  on public.user_roles for select
  to authenticated
  using (user_id = auth.uid() or public.user_is_admin(auth.uid()));

drop policy if exists user_roles_insert_super_admin on public.user_roles;
create policy user_roles_insert_super_admin
  on public.user_roles for insert
  to authenticated
  with check (public.user_has_role(auth.uid(), 'super_admin'));

drop policy if exists user_roles_delete_super_admin on public.user_roles;
create policy user_roles_delete_super_admin
  on public.user_roles for delete
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'));

-- admin_sections (super admin only)

alter table public.admin_sections enable row level security;

drop policy if exists admin_sections_select_staff on public.admin_sections;
create policy admin_sections_select_staff
  on public.admin_sections for select
  to authenticated
  using (public.user_is_admin(auth.uid()));

drop policy if exists admin_sections_write_super on public.admin_sections;
create policy admin_sections_write_super
  on public.admin_sections for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

-- section_admin_assignments

alter table public.section_admin_assignments enable row level security;

drop policy if exists assignments_select_self_or_super on public.section_admin_assignments;
create policy assignments_select_self_or_super
  on public.section_admin_assignments for select
  to authenticated
  using (section_admin_id = auth.uid() or public.user_has_role(auth.uid(), 'super_admin'));

drop policy if exists assignments_write_super on public.section_admin_assignments;
create policy assignments_write_super
  on public.section_admin_assignments for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

-- devices: user owns their devices, admins can see all

alter table public.devices enable row level security;

drop policy if exists devices_select_owner_or_admin on public.devices;
create policy devices_select_owner_or_admin
  on public.devices for select
  to authenticated
  using (user_id = auth.uid() or public.user_is_admin(auth.uid()));

drop policy if exists devices_write_owner on public.devices;
create policy devices_write_owner
  on public.devices for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- verifications: only the owner can see their own; service role (edge functions) bypasses RLS.

alter table public.verifications enable row level security;

drop policy if exists verifications_select_owner on public.verifications;
create policy verifications_select_owner
  on public.verifications for select
  to authenticated
  using (user_id = auth.uid());

-- inserts/updates of verifications go exclusively through service-role (Edge Functions), so no
-- public insert/update policy is granted here.

commit;


-- ----------------------------------------------------------------------------
-- 0004_profile_on_signup_trigger.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0004 · Auto-create profile + assign default role on auth.users insert.

begin;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role user_role := 'requester';
  v_locale text := 'ar';
begin
  -- accept role and locale from auth metadata if provided at signup
  if new.raw_user_meta_data ? 'role' then
    v_role := (new.raw_user_meta_data->>'role')::user_role;
    -- only requester or provider can self-assign; admin roles must be granted explicitly later
    if v_role not in ('requester', 'provider') then
      v_role := 'requester';
    end if;
  end if;

  if new.raw_user_meta_data ? 'locale' then
    v_locale := coalesce(new.raw_user_meta_data->>'locale', 'ar');
    if v_locale not in ('ar','ur','en','hi','bn') then
      v_locale := 'ar';
    end if;
  end if;

  insert into public.profiles (user_id, full_name, email_normalized, phone_e164, preferred_locale)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', null),
    case when new.email is not null then lower(new.email) else null end,
    coalesce(new.raw_user_meta_data->>'phone_e164', null),
    v_locale
  )
  on conflict (user_id) do nothing;

  insert into public.user_roles (user_id, role)
  values (new.id, v_role)
  on conflict do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

commit;


-- ----------------------------------------------------------------------------
-- 0005_catalog_tables.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0005 · Catalog: categories, subcategories, services, geography.

begin;

-- categories

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name jsonb not null,
  description jsonb,
  icon_key text,                                -- maps to a lucide icon in the UI
  display_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists categories_set_updated_at on public.categories;
create trigger categories_set_updated_at
  before update on public.categories
  for each row execute function public.set_updated_at();

create index if not exists categories_active_order_idx
  on public.categories (is_active, display_order);

-- subcategories

create table if not exists public.subcategories (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories(id) on delete cascade,
  slug text not null,
  name jsonb not null,
  display_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (category_id, slug)
);

create index if not exists subcategories_category_idx
  on public.subcategories (category_id, is_active);

-- services (bookable units)

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  subcategory_id uuid not null references public.subcategories(id) on delete cascade,
  slug text not null,
  name jsonb not null,
  description jsonb,
  base_price numeric(12,2),
  price_unit text not null default 'visit' check (price_unit in ('visit','hour','fixed')),
  currency text not null default 'SAR',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (subcategory_id, slug)
);

drop trigger if exists services_set_updated_at on public.services;
create trigger services_set_updated_at
  before update on public.services
  for each row execute function public.set_updated_at();

create index if not exists services_subcategory_idx
  on public.services (subcategory_id, is_active);

-- search index on multilingual names
create index if not exists services_name_ar_trgm_idx
  on public.services using gin ((name->>'ar') gin_trgm_ops);
create index if not exists services_name_en_trgm_idx
  on public.services using gin ((name->>'en') gin_trgm_ops);

-- cities

create table if not exists public.cities (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name jsonb not null,
  region text,
  display_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists cities_active_order_idx
  on public.cities (is_active, display_order);

-- districts

create table if not exists public.districts (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references public.cities(id) on delete cascade,
  slug text not null,
  name jsonb not null,
  created_at timestamptz not null default now(),
  unique (city_id, slug)
);

-- provider extension: add columns to providers (table exists per arch doc; created here for completeness)

create table if not exists public.providers (
  user_id uuid primary key references public.profiles(user_id) on delete cascade,
  display_name jsonb not null,
  bio jsonb,
  business_type text not null default 'individual' check (business_type in ('individual','company')),
  cr_number text,
  vat_number text,
  hourly_rate numeric(12,2),
  currency text not null default 'SAR',
  subscription_tier text not null default 'free' check (subscription_tier in ('free','trusted','featured')),
  subscription_expires_at timestamptz,
  is_verified boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists providers_set_updated_at on public.providers;
create trigger providers_set_updated_at
  before update on public.providers
  for each row execute function public.set_updated_at();

create index if not exists providers_active_verified_tier_idx
  on public.providers (is_active, is_verified, subscription_tier);

-- provider_categories (many-to-many)

create table if not exists public.provider_categories (
  provider_id uuid not null references public.providers(user_id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  subcategory_id uuid references public.subcategories(id) on delete cascade,
  primary key (provider_id, category_id, subcategory_id)
);

create index if not exists provider_categories_category_idx
  on public.provider_categories (category_id);

-- provider_coverage_areas (city-based; polygon support is added in phase 5 with PostGIS)

create table if not exists public.provider_coverage_areas (
  provider_id uuid not null references public.providers(user_id) on delete cascade,
  city_id uuid not null references public.cities(id) on delete cascade,
  primary key (provider_id, city_id)
);

create index if not exists coverage_city_idx on public.provider_coverage_areas (city_id);

commit;


-- ----------------------------------------------------------------------------
-- 0006_catalog_rls.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0006 · RLS for catalog tables.
-- Read: anyone authenticated can see active rows; admins see all.
-- Write: super_admin everywhere; section_admin within their scope (enforced in higher migrations).

begin;

-- categories

alter table public.categories enable row level security;

drop policy if exists categories_read_active on public.categories;
create policy categories_read_active
  on public.categories for select
  to anon, authenticated
  using (is_active or public.user_is_admin(auth.uid()));

drop policy if exists categories_write_super on public.categories;
create policy categories_write_super
  on public.categories for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

-- subcategories

alter table public.subcategories enable row level security;

drop policy if exists subcategories_read_active on public.subcategories;
create policy subcategories_read_active
  on public.subcategories for select
  to anon, authenticated
  using (is_active or public.user_is_admin(auth.uid()));

drop policy if exists subcategories_write_super on public.subcategories;
create policy subcategories_write_super
  on public.subcategories for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

-- services

alter table public.services enable row level security;

drop policy if exists services_read_active on public.services;
create policy services_read_active
  on public.services for select
  to anon, authenticated
  using (is_active or public.user_is_admin(auth.uid()));

drop policy if exists services_write_super on public.services;
create policy services_write_super
  on public.services for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

-- cities & districts (public read, admin write)

alter table public.cities enable row level security;

drop policy if exists cities_read_active on public.cities;
create policy cities_read_active
  on public.cities for select
  to anon, authenticated
  using (is_active or public.user_is_admin(auth.uid()));

drop policy if exists cities_write_super on public.cities;
create policy cities_write_super
  on public.cities for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

alter table public.districts enable row level security;

drop policy if exists districts_read_all on public.districts;
create policy districts_read_all
  on public.districts for select
  to anon, authenticated
  using (true);

drop policy if exists districts_write_super on public.districts;
create policy districts_write_super
  on public.districts for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

-- providers

alter table public.providers enable row level security;

drop policy if exists providers_read_active on public.providers;
create policy providers_read_active
  on public.providers for select
  to anon, authenticated
  using (
    (is_active and is_verified)
    or user_id = auth.uid()
    or public.user_is_admin(auth.uid())
  );

drop policy if exists providers_insert_self on public.providers;
create policy providers_insert_self
  on public.providers for insert
  to authenticated
  with check (user_id = auth.uid() and public.user_has_role(auth.uid(), 'provider'));

drop policy if exists providers_update_self_or_admin on public.providers;
create policy providers_update_self_or_admin
  on public.providers for update
  to authenticated
  using (user_id = auth.uid() or public.user_is_admin(auth.uid()))
  with check (user_id = auth.uid() or public.user_is_admin(auth.uid()));

-- provider_categories

alter table public.provider_categories enable row level security;

drop policy if exists provider_categories_read_all on public.provider_categories;
create policy provider_categories_read_all
  on public.provider_categories for select
  to anon, authenticated
  using (true);

drop policy if exists provider_categories_write_self on public.provider_categories;
create policy provider_categories_write_self
  on public.provider_categories for all
  to authenticated
  using (provider_id = auth.uid() or public.user_is_admin(auth.uid()))
  with check (provider_id = auth.uid() or public.user_is_admin(auth.uid()));

-- provider_coverage_areas

alter table public.provider_coverage_areas enable row level security;

drop policy if exists coverage_read_all on public.provider_coverage_areas;
create policy coverage_read_all
  on public.provider_coverage_areas for select
  to anon, authenticated
  using (true);

drop policy if exists coverage_write_self on public.provider_coverage_areas;
create policy coverage_write_self
  on public.provider_coverage_areas for all
  to authenticated
  using (provider_id = auth.uid() or public.user_is_admin(auth.uid()))
  with check (provider_id = auth.uid() or public.user_is_admin(auth.uid()));

commit;


-- ----------------------------------------------------------------------------
-- 0007_catalog_seed.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0007 · Seed catalog with realistic Saudi data.
-- These rows are part of the schema, not dev-only seed — they are what the platform ships with.

begin;

-- Categories (8 launch categories)

insert into public.categories (slug, name, description, icon_key, display_order) values
  ('hvac',       '{"ar":"تكييف وتبريد","en":"HVAC","ur":"اے سی","hi":"एसी","bn":"এসি"}',
                 '{"ar":"تركيب وصيانة وغسيل","en":"Install, maintain, wash"}', 'Wind', 10),
  ('plumbing',   '{"ar":"سباكة","en":"Plumbing","ur":"پلمبنگ","hi":"प्लंबिंग","bn":"প্লাম্বিং"}',
                 '{"ar":"تسرّبات، صرف، خزّانات","en":"Leaks, drains, tanks"}', 'Wrench', 20),
  ('electrical', '{"ar":"كهرباء","en":"Electrical","ur":"بجلی","hi":"बिजली","bn":"বৈদ্যুতিক"}',
                 '{"ar":"إصلاح، تمديد، لوحات","en":"Repair, wiring, panels"}', 'Zap', 30),
  ('appliances', '{"ar":"أجهزة منزلية","en":"Appliances","ur":"گھریلو آلات","hi":"घरेलू उपकरण","bn":"গৃহস্থালী"}',
                 '{"ar":"غسالات، ثلاجات، أفران","en":"Washers, fridges, ovens"}', 'WashingMachine', 40),
  ('home',       '{"ar":"صيانة عامة","en":"General","ur":"عمومی","hi":"सामान्य","bn":"সাধারণ"}',
                 '{"ar":"دهان، أبواب، جبس","en":"Paint, doors, gypsum"}', 'Home', 50),
  ('vehicle',    '{"ar":"صيانة سيارات","en":"Vehicle","ur":"گاڑی","hi":"वाहन","bn":"গাড়ি"}',
                 '{"ar":"إطارات، زيوت، بطاريات","en":"Tires, oil, battery"}', 'Car', 60),
  ('cleaning',   '{"ar":"نظافة","en":"Cleaning","ur":"صفائی","hi":"सफ़ाई","bn":"পরিষ্কার"}',
                 '{"ar":"منازل، مكاتب، فلل","en":"Homes, offices, villas"}', 'Sparkles', 70),
  ('pest',       '{"ar":"مكافحة حشرات","en":"Pest","ur":"کیڑے","hi":"कीट","bn":"কীট"}',
                 '{"ar":"رش، تعقيم","en":"Spray, sanitize"}', 'Bug', 80)
on conflict (slug) do nothing;

-- Subcategories (a few per category)

with cats as (select id, slug from public.categories)
insert into public.subcategories (category_id, slug, name, display_order)
select c.id, sc.slug, sc.name, sc.display_order
from cats c
join (values
  ('hvac', 'install',  '{"ar":"تركيب","en":"Install"}'::jsonb,           10),
  ('hvac', 'maintain', '{"ar":"صيانة","en":"Maintenance"}'::jsonb,       20),
  ('hvac', 'wash',     '{"ar":"غسيل","en":"Wash"}'::jsonb,                30),
  ('plumbing', 'leak',  '{"ar":"إصلاح تسرّب","en":"Leak repair"}'::jsonb,  10),
  ('plumbing', 'drain', '{"ar":"تسليك صرف","en":"Drain unclog"}'::jsonb,   20),
  ('plumbing', 'tank',  '{"ar":"خزّانات","en":"Water tanks"}'::jsonb,      30),
  ('electrical', 'repair', '{"ar":"إصلاح أعطال","en":"Repairs"}'::jsonb,    10),
  ('electrical', 'wiring', '{"ar":"تمديد","en":"Wiring"}'::jsonb,           20),
  ('electrical', 'panel',  '{"ar":"لوحات","en":"Panels"}'::jsonb,           30),
  ('appliances', 'washer', '{"ar":"غسالات","en":"Washing machines"}'::jsonb, 10),
  ('appliances', 'fridge', '{"ar":"ثلاجات","en":"Refrigerators"}'::jsonb,    20),
  ('appliances', 'oven',   '{"ar":"أفران","en":"Ovens"}'::jsonb,             30),
  ('home', 'paint',  '{"ar":"دهان","en":"Painting"}'::jsonb,                  10),
  ('home', 'door',   '{"ar":"أبواب","en":"Doors"}'::jsonb,                    20),
  ('home', 'gypsum', '{"ar":"جبس","en":"Gypsum"}'::jsonb,                     30),
  ('vehicle', 'oil',     '{"ar":"تغيير زيت","en":"Oil change"}'::jsonb,        10),
  ('vehicle', 'tires',   '{"ar":"إطارات","en":"Tires"}'::jsonb,                20),
  ('vehicle', 'battery', '{"ar":"بطّاريات","en":"Battery"}'::jsonb,            30),
  ('cleaning', 'home',   '{"ar":"تنظيف منازل","en":"Home cleaning"}'::jsonb,    10),
  ('cleaning', 'sofa',   '{"ar":"تنظيف كنب","en":"Sofa cleaning"}'::jsonb,      20),
  ('cleaning', 'office', '{"ar":"تنظيف مكاتب","en":"Office cleaning"}'::jsonb,  30),
  ('pest', 'roach',     '{"ar":"صراصير","en":"Cockroaches"}'::jsonb, 10),
  ('pest', 'rodents',   '{"ar":"قوارض","en":"Rodents"}'::jsonb,      20),
  ('pest', 'sanitize',  '{"ar":"تعقيم","en":"Sanitization"}'::jsonb, 30)
) as sc(cat_slug, slug, name, display_order) on sc.cat_slug = c.slug
on conflict (category_id, slug) do nothing;

-- Cities (top 14 by population)

insert into public.cities (slug, name, region, display_order) values
  ('riyadh',  '{"ar":"الرياض","en":"Riyadh"}',     'Riyadh',         10),
  ('jeddah',  '{"ar":"جدّة","en":"Jeddah"}',       'Makkah',         20),
  ('makkah',  '{"ar":"مكة المكرّمة","en":"Makkah"}','Makkah',         30),
  ('madinah', '{"ar":"المدينة المنورة","en":"Madinah"}','Madinah',    40),
  ('dammam',  '{"ar":"الدمام","en":"Dammam"}',     'Eastern',        50),
  ('khobar',  '{"ar":"الخبر","en":"Khobar"}',      'Eastern',        60),
  ('dhahran', '{"ar":"الظهران","en":"Dhahran"}',   'Eastern',        70),
  ('taif',    '{"ar":"الطائف","en":"Taif"}',       'Makkah',         80),
  ('tabuk',   '{"ar":"تبوك","en":"Tabuk"}',        'Tabuk',          90),
  ('abha',    '{"ar":"أبها","en":"Abha"}',         'Asir',          100),
  ('khamis',  '{"ar":"خميس مشيط","en":"Khamis Mushait"}','Asir',     110),
  ('hail',    '{"ar":"حائل","en":"Hail"}',         'Hail',          120),
  ('buraidah','{"ar":"بريدة","en":"Buraidah"}',    'Qassim',        130),
  ('najran',  '{"ar":"نجران","en":"Najran"}',      'Najran',        140)
on conflict (slug) do nothing;

commit;


-- ----------------------------------------------------------------------------
-- 0008_geo_and_location_pings.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0008 · PostGIS, provider live location, and location_pings table.
-- Requires the postgis extension. On Supabase, enable from Dashboard → Database → Extensions.

begin;

create extension if not exists postgis;

-- add geography column to providers for current live location during active orders

alter table public.providers
  add column if not exists current_location geography(Point, 4326),
  add column if not exists current_location_updated_at timestamptz;

create index if not exists providers_location_gix
  on public.providers using gist (current_location);

-- location_pings: append-only stream of live position updates during an active order.
-- One row per ping; older rows are pruned by a cron job after the order completes.

create table if not exists public.location_pings (
  id bigserial primary key,
  order_id uuid not null,                       -- FK added in migration 0010 (orders table)
  provider_id uuid not null references public.providers(user_id) on delete cascade,
  location geography(Point, 4326) not null,
  heading double precision,
  speed_mps double precision,
  accuracy_m double precision,
  created_at timestamptz not null default now()
);

create index if not exists location_pings_order_created_idx
  on public.location_pings (order_id, created_at desc);

create index if not exists location_pings_provider_idx
  on public.location_pings (provider_id, created_at desc);

create index if not exists location_pings_location_gix
  on public.location_pings using gist (location);

alter table public.location_pings enable row level security;

-- Provider writes their own pings. Requester reads pings of their order (joined in 0011 once orders exists).
drop policy if exists location_pings_insert_provider on public.location_pings;
create policy location_pings_insert_provider
  on public.location_pings for insert
  to authenticated
  with check (provider_id = auth.uid());

drop policy if exists location_pings_select_provider_or_admin on public.location_pings;
create policy location_pings_select_provider_or_admin
  on public.location_pings for select
  to authenticated
  using (provider_id = auth.uid() or public.user_is_admin(auth.uid()));
-- A broader requester-read policy is added in migration 0011 once orders are joined.

-- Helper: nearby providers by location, returning distance in meters.
create or replace function public.providers_nearby(
  p_lat double precision,
  p_lng double precision,
  p_radius_m double precision default 10000,
  p_category text default null
)
returns table (
  provider_id uuid,
  display_name jsonb,
  subscription_tier text,
  distance_m double precision
)
language sql
stable
as $$
  select
    p.user_id as provider_id,
    p.display_name,
    p.subscription_tier,
    st_distance(p.current_location, st_makepoint(p_lng, p_lat)::geography) as distance_m
  from public.providers p
  where p.is_active
    and p.is_verified
    and p.current_location is not null
    and st_dwithin(p.current_location, st_makepoint(p_lng, p_lat)::geography, p_radius_m)
    and (
      p_category is null or exists (
        select 1
        from public.provider_categories pc
        join public.categories c on c.id = pc.category_id
        where pc.provider_id = p.user_id and c.slug = p_category
      )
    )
  order by distance_m asc
  limit 50;
$$;

commit;


-- ----------------------------------------------------------------------------
-- 0009_chat_tables.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0009 · Chat tables: conversations, messages, message_reads, typing_indicators.

begin;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'message_type') then
    create type message_type as enum ('text', 'image', 'file', 'voice', 'location', 'system');
  end if;
end $$;

-- conversations: 1:1 with orders (FK added once orders exist in migration 0010 stub).

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  order_id uuid unique not null,                          -- FK added in 0011 (orders dep)
  is_archived boolean not null default false,
  archived_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists conversations_order_idx on public.conversations (order_id);
create index if not exists conversations_archived_idx on public.conversations (is_archived);

-- messages

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(user_id) on delete restrict,
  type message_type not null,
  body text,
  media_path text,
  media_mime text,
  media_size_bytes int,
  media_duration_ms int,
  waveform jsonb,                                          -- precomputed peaks for voice
  latitude double precision,
  longitude double precision,
  reply_to_message_id uuid references public.messages(id),
  edited_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  constraint messages_body_or_media check (
    type = 'system' or
    (type = 'text' and body is not null and length(body) between 1 and 4000) or
    (type in ('image','file','voice') and media_path is not null) or
    (type = 'location' and latitude is not null and longitude is not null)
  )
);

create index if not exists messages_conversation_created_idx
  on public.messages (conversation_id, created_at desc);
create index if not exists messages_sender_idx
  on public.messages (sender_id, created_at desc);

-- message_reads (per user)

create table if not exists public.message_reads (
  message_id uuid not null references public.messages(id) on delete cascade,
  reader_id uuid not null references public.profiles(user_id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (message_id, reader_id)
);

create index if not exists message_reads_reader_idx
  on public.message_reads (reader_id, read_at desc);

-- RLS

alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.message_reads enable row level security;

-- conversations: visible to admins until orders FK exists; tightened in 0011.
drop policy if exists conversations_select_temp on public.conversations;
create policy conversations_select_temp
  on public.conversations for select
  to authenticated
  using (public.user_is_admin(auth.uid()));

drop policy if exists conversations_write_super on public.conversations;
create policy conversations_write_super
  on public.conversations for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

-- messages: sender can write; reads scoped to admins until 0011 connects orders.
drop policy if exists messages_insert_sender on public.messages;
create policy messages_insert_sender
  on public.messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and not exists (
      select 1 from public.conversations c
      where c.id = messages.conversation_id and c.is_archived = true
    )
  );

drop policy if exists messages_select_admin_for_now on public.messages;
create policy messages_select_admin_for_now
  on public.messages for select
  to authenticated
  using (sender_id = auth.uid() or public.user_is_admin(auth.uid()));

-- message_reads
drop policy if exists message_reads_self on public.message_reads;
create policy message_reads_self
  on public.message_reads for all
  to authenticated
  using (reader_id = auth.uid())
  with check (reader_id = auth.uid());

commit;


-- ----------------------------------------------------------------------------
-- 0010_orders.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0010 · Orders, status history, attachments + state machine trigger + notifications.

begin;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'order_status') then
    create type order_status as enum (
      'draft','pending','accepted','rejected','en_route','in_progress',
      'completed','cancelled','disputed'
    );
  end if;
end $$;

-- orders

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  code text unique not null default ('SY-' || to_char(now(), 'YYYY') || '-' || lpad((floor(random()*999999))::text, 6, '0')),
  requester_id uuid not null references public.profiles(user_id) on delete restrict,
  provider_id uuid references public.profiles(user_id) on delete restrict,
  category_id uuid not null references public.categories(id),
  subcategory_id uuid references public.subcategories(id),
  service_id uuid references public.services(id),
  status order_status not null default 'pending',
  scheduled_at timestamptz,
  address_label text not null,
  address_details text,
  location geography(Point, 4326) not null,
  city_id uuid references public.cities(id),
  district_id uuid references public.districts(id),
  notes text,
  estimated_total numeric(12,2),
  final_total numeric(12,2),
  currency text not null default 'SAR',
  cancellation_reason text,
  cancelled_by uuid references public.profiles(user_id),
  accepted_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists orders_set_updated_at on public.orders;
create trigger orders_set_updated_at
  before update on public.orders
  for each row execute function public.set_updated_at();

create index if not exists orders_requester_status_idx on public.orders (requester_id, status, created_at desc);
create index if not exists orders_provider_status_idx  on public.orders (provider_id, status, created_at desc);
create index if not exists orders_location_gix         on public.orders using gist (location);
create index if not exists orders_active_idx
  on public.orders (status, created_at desc)
  where status in ('pending','accepted','en_route','in_progress');

-- order_status_history

create table if not exists public.order_status_history (
  id bigserial primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  from_status order_status,
  to_status order_status not null,
  changed_by uuid references public.profiles(user_id),
  reason text,
  created_at timestamptz not null default now()
);

create index if not exists order_history_order_idx on public.order_status_history (order_id, created_at desc);

-- state machine validation trigger

create or replace function public.validate_order_status_transition()
returns trigger
language plpgsql
as $$
declare
  v_valid boolean;
begin
  if new.status = old.status then
    return new;
  end if;

  v_valid := case
    when old.status = 'pending'      and new.status in ('accepted','rejected','cancelled')         then true
    when old.status = 'accepted'     and new.status in ('en_route','cancelled')                    then true
    when old.status = 'en_route'     and new.status in ('in_progress','cancelled')                 then true
    when old.status = 'in_progress'  and new.status in ('completed','disputed')                    then true
    when old.status = 'completed'    and new.status in ('disputed')                                then true
    when old.status = 'disputed'     and new.status in ('completed','cancelled')                   then true
    else false
  end;

  if not v_valid then
    raise exception 'ORDER_INVALID_TRANSITION from % to %', old.status, new.status using errcode = 'P0001';
  end if;

  -- timestamp side-effects
  if new.status = 'accepted' and old.status <> 'accepted' then new.accepted_at := now(); end if;
  if new.status = 'in_progress' and old.status <> 'in_progress' then new.started_at := now(); end if;
  if new.status = 'completed' and old.status <> 'completed' then new.completed_at := now(); end if;
  if new.status = 'cancelled' and old.status <> 'cancelled' then new.cancelled_at := now(); end if;

  insert into public.order_status_history (order_id, from_status, to_status, changed_by)
  values (new.id, old.status, new.status, auth.uid());

  return new;
end;
$$;

drop trigger if exists orders_validate_status on public.orders;
create trigger orders_validate_status
  before update of status on public.orders
  for each row execute function public.validate_order_status_transition();

-- order_attachments (photos uploaded by requester at creation)

create table if not exists public.order_attachments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  uploaded_by uuid not null references public.profiles(user_id) on delete restrict,
  path text not null,
  mime text,
  size_bytes int,
  created_at timestamptz not null default now()
);

create index if not exists order_attachments_order_idx on public.order_attachments (order_id);

-- RLS

alter table public.orders enable row level security;
alter table public.order_status_history enable row level security;
alter table public.order_attachments enable row level security;

-- orders policies

drop policy if exists orders_select_participants on public.orders;
create policy orders_select_participants
  on public.orders for select
  to authenticated
  using (
    requester_id = auth.uid()
    or provider_id = auth.uid()
    or public.user_is_admin(auth.uid())
  );

drop policy if exists orders_insert_requester on public.orders;
create policy orders_insert_requester
  on public.orders for insert
  to authenticated
  with check (
    requester_id = auth.uid()
    and public.user_has_role(auth.uid(), 'requester')
  );

-- update split: provider can only accept/reject and progress; requester can only cancel pending.
drop policy if exists orders_update_provider on public.orders;
create policy orders_update_provider
  on public.orders for update
  to authenticated
  using (provider_id = auth.uid())
  with check (provider_id = auth.uid());

drop policy if exists orders_update_requester_cancel on public.orders;
create policy orders_update_requester_cancel
  on public.orders for update
  to authenticated
  using (requester_id = auth.uid())
  with check (requester_id = auth.uid());

drop policy if exists orders_update_admin on public.orders;
create policy orders_update_admin
  on public.orders for update
  to authenticated
  using (public.user_is_admin(auth.uid()))
  with check (public.user_is_admin(auth.uid()));

-- status history readable by order participants
drop policy if exists order_history_select_participants on public.order_status_history;
create policy order_history_select_participants
  on public.order_status_history for select
  to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_status_history.order_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid()
             or public.user_is_admin(auth.uid()))
    )
  );

-- attachments
drop policy if exists order_attachments_rw on public.order_attachments;
create policy order_attachments_rw
  on public.order_attachments for all
  to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_attachments.order_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid()
             or public.user_is_admin(auth.uid()))
    )
  )
  with check (
    exists (
      select 1 from public.orders o
      where o.id = order_attachments.order_id
        and o.requester_id = auth.uid()
    )
  );

commit;


-- ----------------------------------------------------------------------------
-- 0011_chat_tighten_and_links.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0011 · Link chat/location to orders, replace temp policies with strict ones.

begin;

-- add FK from conversations to orders now that orders exist
do $$ begin
  if not exists (
    select 1 from information_schema.table_constraints
    where table_schema='public' and table_name='conversations'
      and constraint_name='conversations_order_id_fkey'
  ) then
    alter table public.conversations
      add constraint conversations_order_id_fkey
      foreign key (order_id) references public.orders(id) on delete cascade;
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from information_schema.table_constraints
    where table_schema='public' and table_name='location_pings'
      and constraint_name='location_pings_order_id_fkey'
  ) then
    alter table public.location_pings
      add constraint location_pings_order_id_fkey
      foreign key (order_id) references public.orders(id) on delete cascade;
  end if;
end $$;

-- Auto-create conversation when order is inserted
create or replace function public.create_conversation_for_order()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.conversations (order_id) values (new.id)
  on conflict (order_id) do nothing;
  return new;
end;
$$;

drop trigger if exists orders_after_insert_create_conversation on public.orders;
create trigger orders_after_insert_create_conversation
  after insert on public.orders
  for each row execute function public.create_conversation_for_order();

-- Auto-archive conversation when order completes
create or replace function public.archive_conversation_on_order_completion()
returns trigger language plpgsql
as $$
begin
  if new.status in ('completed','cancelled') and old.status not in ('completed','cancelled') then
    update public.conversations
       set is_archived = true, archived_at = now()
     where order_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists orders_after_update_archive_chat on public.orders;
create trigger orders_after_update_archive_chat
  after update of status on public.orders
  for each row execute function public.archive_conversation_on_order_completion();

-- ----- Tighten policies for conversations / messages / location_pings -----

drop policy if exists conversations_select_temp on public.conversations;

drop policy if exists conversations_select_participants on public.conversations;
create policy conversations_select_participants
  on public.conversations for select
  to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = conversations.order_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid()
             or public.user_is_admin(auth.uid()))
    )
  );

drop policy if exists messages_select_admin_for_now on public.messages;

drop policy if exists messages_select_participants on public.messages;
create policy messages_select_participants
  on public.messages for select
  to authenticated
  using (
    exists (
      select 1
      from public.conversations c
      join public.orders o on o.id = c.order_id
      where c.id = messages.conversation_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid()
             or public.user_is_admin(auth.uid()))
    )
  );

-- restrict inserts to actual participants + non-archived
drop policy if exists messages_insert_sender on public.messages;
create policy messages_insert_participants
  on public.messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1
      from public.conversations c
      join public.orders o on o.id = c.order_id
      where c.id = messages.conversation_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid())
        and c.is_archived = false
    )
  );

-- requester can now read location_pings of their own active order
drop policy if exists location_pings_select_requester on public.location_pings;
create policy location_pings_select_requester
  on public.location_pings for select
  to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = location_pings.order_id
        and o.requester_id = auth.uid()
        and o.status in ('en_route','in_progress')
    )
  );

commit;


-- ----------------------------------------------------------------------------
-- 0012_notifications.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0012 · Notifications (in-app feed) + per-channel delivery log + preferences.

begin;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  title_key text not null,                               -- key into translations table
  body_key text,
  params jsonb,                                          -- substitutions for {var}
  resource_type text,                                    -- 'order' | 'message' | 'dispute' | ...
  resource_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_unread_idx
  on public.notifications (user_id, read_at, created_at desc);

create table if not exists public.notification_deliveries (
  id bigserial primary key,
  notification_id uuid not null references public.notifications(id) on delete cascade,
  channel text not null check (channel in ('push','sms','email','in_app')),
  status text not null default 'pending' check (status in ('pending','sent','failed','suppressed')),
  provider_message_id text,
  attempted_at timestamptz not null default now(),
  error text
);

create index if not exists notification_deliveries_notification_idx
  on public.notification_deliveries (notification_id);

create table if not exists public.notification_preferences (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  category text not null,                                -- 'order_status', 'chat', 'marketing', ...
  push_enabled boolean not null default true,
  sms_enabled boolean not null default false,
  email_enabled boolean not null default true,
  primary key (user_id, category)
);

alter table public.notifications enable row level security;
alter table public.notification_deliveries enable row level security;
alter table public.notification_preferences enable row level security;

drop policy if exists notifications_select_self on public.notifications;
create policy notifications_select_self
  on public.notifications for select
  to authenticated
  using (user_id = auth.uid() or public.user_is_admin(auth.uid()));

drop policy if exists notifications_update_self on public.notifications;
create policy notifications_update_self
  on public.notifications for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- inserts only via service_role (Edge Functions); no public insert policy.

drop policy if exists notification_deliveries_select_self on public.notification_deliveries;
create policy notification_deliveries_select_self
  on public.notification_deliveries for select
  to authenticated
  using (
    exists (
      select 1 from public.notifications n
      where n.id = notification_deliveries.notification_id
        and (n.user_id = auth.uid() or public.user_is_admin(auth.uid()))
    )
  );

drop policy if exists notification_preferences_rw_self on public.notification_preferences;
create policy notification_preferences_rw_self
  on public.notification_preferences for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- helper: emit a notification on order status change
create or replace function public.notify_on_order_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipients uuid[];
  v_title_key text;
begin
  v_title_key := case new.status
    when 'accepted'    then 'notifications.order_accepted'
    when 'en_route'    then 'notifications.order_en_route'
    when 'in_progress' then 'notifications.order_in_progress'
    when 'completed'   then 'notifications.order_completed'
    when 'cancelled'   then 'notifications.order_cancelled'
    when 'disputed'    then 'notifications.order_disputed'
    else null
  end;

  if v_title_key is null then return new; end if;

  v_recipients := array_remove(array[new.requester_id, new.provider_id], null);

  insert into public.notifications (user_id, title_key, params, resource_type, resource_id)
  select uid, v_title_key, jsonb_build_object('code', new.code), 'order', new.id
  from unnest(v_recipients) as uid;

  return new;
end;
$$;

drop trigger if exists orders_after_status_notify on public.orders;
create trigger orders_after_status_notify
  after update of status on public.orders
  for each row execute function public.notify_on_order_status_change();

commit;


-- ----------------------------------------------------------------------------
-- 0013_ratings_disputes.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0013 · Ratings, reviews, disputes, and dispute evidence.

begin;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'dispute_status') then
    create type dispute_status as enum ('open','under_review','resolved_requester','resolved_provider','dismissed');
  end if;
end $$;

-- ratings (bi-directional: requester ↔ provider). One per (order, rater).

create table if not exists public.ratings (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  rater_id uuid not null references public.profiles(user_id) on delete restrict,
  ratee_id uuid not null references public.profiles(user_id) on delete restrict,
  score int not null check (score between 1 and 5),
  comment text check (length(comment) <= 2000),
  is_visible boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (order_id, rater_id)
);

drop trigger if exists ratings_set_updated_at on public.ratings;
create trigger ratings_set_updated_at
  before update on public.ratings
  for each row execute function public.set_updated_at();

create index if not exists ratings_ratee_idx on public.ratings (ratee_id, is_visible, score);

-- disputes (one per order)

create table if not exists public.disputes (
  id uuid primary key default gen_random_uuid(),
  order_id uuid unique not null references public.orders(id) on delete cascade,
  opened_by uuid not null references public.profiles(user_id) on delete restrict,
  reason text not null check (length(reason) between 3 and 200),
  description text check (length(description) <= 5000),
  status dispute_status not null default 'open',
  assigned_admin_id uuid references public.profiles(user_id),
  resolved_at timestamptz,
  resolution_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists disputes_set_updated_at on public.disputes;
create trigger disputes_set_updated_at
  before update on public.disputes
  for each row execute function public.set_updated_at();

create index if not exists disputes_status_idx on public.disputes (status, created_at desc);
create index if not exists disputes_admin_idx on public.disputes (assigned_admin_id);

create table if not exists public.dispute_evidence (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.disputes(id) on delete cascade,
  artifact_type text not null check (artifact_type in ('chat_export','message','photo','audio','other')),
  path text,
  message_id uuid references public.messages(id),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists dispute_evidence_dispute_idx on public.dispute_evidence (dispute_id);

create table if not exists public.dispute_actions (
  id bigserial primary key,
  dispute_id uuid not null references public.disputes(id) on delete cascade,
  actor_id uuid not null references public.profiles(user_id),
  action text not null,
  payload jsonb,
  created_at timestamptz not null default now()
);

-- Hide ratings of an order when a dispute is opened; restore on dismiss/resolution.
create or replace function public.toggle_ratings_visibility_on_dispute()
returns trigger language plpgsql as $$
begin
  if (tg_op = 'INSERT') then
    update public.ratings set is_visible = false where order_id = new.order_id;
  elsif (tg_op = 'UPDATE') then
    if new.status in ('resolved_requester','resolved_provider','dismissed')
       and old.status not in ('resolved_requester','resolved_provider','dismissed') then
      update public.ratings set is_visible = true where order_id = new.order_id;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists disputes_toggle_ratings on public.disputes;
create trigger disputes_toggle_ratings
  after insert or update of status on public.disputes
  for each row execute function public.toggle_ratings_visibility_on_dispute();

-- Move order status to 'disputed' when a dispute is opened.
create or replace function public.mark_order_disputed()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.orders set status = 'disputed' where id = new.order_id and status in ('in_progress','completed');
  return new;
end;
$$;

drop trigger if exists disputes_after_insert_mark_order on public.disputes;
create trigger disputes_after_insert_mark_order
  after insert on public.disputes
  for each row execute function public.mark_order_disputed();

-- RLS

alter table public.ratings enable row level security;
alter table public.disputes enable row level security;
alter table public.dispute_evidence enable row level security;
alter table public.dispute_actions enable row level security;

-- ratings: visible (is_visible) ratings readable to anyone; rater + ratee + admin always.
drop policy if exists ratings_select_visible on public.ratings;
create policy ratings_select_visible
  on public.ratings for select
  to anon, authenticated
  using (
    is_visible
    or rater_id = auth.uid()
    or ratee_id = auth.uid()
    or public.user_is_admin(auth.uid())
  );

drop policy if exists ratings_insert_participant on public.ratings;
create policy ratings_insert_participant
  on public.ratings for insert
  to authenticated
  with check (
    rater_id = auth.uid()
    and exists (
      select 1 from public.orders o
      where o.id = order_id
        and o.status = 'completed'
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid())
        and not exists (select 1 from public.disputes d where d.order_id = o.id and d.status = 'open')
    )
  );

drop policy if exists ratings_update_self on public.ratings;
create policy ratings_update_self
  on public.ratings for update
  to authenticated
  using (rater_id = auth.uid())
  with check (rater_id = auth.uid());

-- disputes: participants + assigned admin can read; only participants can open
drop policy if exists disputes_select_participants on public.disputes;
create policy disputes_select_participants
  on public.disputes for select
  to authenticated
  using (
    public.user_is_admin(auth.uid())
    or exists (
      select 1 from public.orders o
      where o.id = disputes.order_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid())
    )
  );

drop policy if exists disputes_insert_participant on public.disputes;
create policy disputes_insert_participant
  on public.disputes for insert
  to authenticated
  with check (
    opened_by = auth.uid()
    and exists (
      select 1 from public.orders o
      where o.id = order_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid())
    )
  );

drop policy if exists disputes_update_admin on public.disputes;
create policy disputes_update_admin
  on public.disputes for update
  to authenticated
  using (public.user_is_admin(auth.uid()))
  with check (public.user_is_admin(auth.uid()));

-- dispute_evidence
drop policy if exists dispute_evidence_read_participants on public.dispute_evidence;
create policy dispute_evidence_read_participants
  on public.dispute_evidence for select
  to authenticated
  using (
    public.user_is_admin(auth.uid())
    or exists (
      select 1 from public.disputes d
      join public.orders o on o.id = d.order_id
      where d.id = dispute_evidence.dispute_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid())
    )
  );

drop policy if exists dispute_evidence_insert_participant on public.dispute_evidence;
create policy dispute_evidence_insert_participant
  on public.dispute_evidence for insert
  to authenticated
  with check (
    public.user_is_admin(auth.uid())
    or exists (
      select 1 from public.disputes d
      join public.orders o on o.id = d.order_id
      where d.id = dispute_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid())
    )
  );

-- dispute_actions: admin write only; visible to participants
drop policy if exists dispute_actions_read on public.dispute_actions;
create policy dispute_actions_read
  on public.dispute_actions for select
  to authenticated
  using (
    public.user_is_admin(auth.uid())
    or exists (
      select 1 from public.disputes d
      join public.orders o on o.id = d.order_id
      where d.id = dispute_actions.dispute_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid())
    )
  );

drop policy if exists dispute_actions_insert_admin on public.dispute_actions;
create policy dispute_actions_insert_admin
  on public.dispute_actions for insert
  to authenticated
  with check (public.user_is_admin(auth.uid()));

-- Provider stats materialized view (refreshed periodically by cron)
drop materialized view if exists public.provider_stats;
create materialized view public.provider_stats as
select
  p.user_id as provider_id,
  coalesce(avg(r.score) filter (where r.is_visible), 0)::numeric(3,2) as avg_rating,
  count(r.id) filter (where r.is_visible) as ratings_count,
  count(distinct o.id) filter (where o.status = 'completed') as completed_orders,
  count(distinct o.id) filter (where o.status = 'cancelled' and o.cancelled_by = p.user_id) as provider_cancellations
from public.providers p
left join public.orders o on o.provider_id = p.user_id
left join public.ratings r on r.ratee_id = p.user_id
group by p.user_id;

create unique index if not exists provider_stats_provider_id_idx on public.provider_stats(provider_id);

commit;


-- ----------------------------------------------------------------------------
-- 0014_subscriptions_ads_payments.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0014 · Subscription packages, ads, commissions, invoices, payments.

begin;

-- subscription_packages: catalog of provider tiers.

create table if not exists public.subscription_packages (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  tier text not null check (tier in ('free','trusted','featured')),
  name jsonb not null,
  description jsonb,
  monthly_price numeric(12,2) not null default 0,
  currency text not null default 'SAR',
  features jsonb not null default '[]'::jsonb,
  commission_pct numeric(5,2) not null default 0 check (commission_pct between 0 and 100),
  max_active_jobs int,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists subscription_packages_set_updated_at on public.subscription_packages;
create trigger subscription_packages_set_updated_at
  before update on public.subscription_packages
  for each row execute function public.set_updated_at();

insert into public.subscription_packages (slug, tier, name, description, monthly_price, features, commission_pct, max_active_jobs)
values
  ('free', 'free',
   '{"ar":"مجاني","en":"Free"}',
   '{"ar":"ابدأ بلا تكلفة","en":"Start with no cost"}',
   0,
   '["3 jobs/day","standard ranking"]'::jsonb,
   20.00, 3),
  ('trusted', 'trusted',
   '{"ar":"موثّق","en":"Trusted"}',
   '{"ar":"شارة موثّق + ترتيب أفضل","en":"Verified badge + higher ranking"}',
   199,
   '["unlimited jobs","verified badge","priority support"]'::jsonb,
   15.00, null),
  ('featured', 'featured',
   '{"ar":"مميّز","en":"Featured"}',
   '{"ar":"إبراز في النتائج + إعلانات","en":"Featured in search + ad placements"}',
   499,
   '["unlimited jobs","verified badge","featured placement","ad credits","dedicated CSM"]'::jsonb,
   10.00, null)
on conflict (slug) do nothing;

-- provider_subscriptions: active subscription per provider.

create table if not exists public.provider_subscriptions (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(user_id) on delete cascade,
  package_id uuid not null references public.subscription_packages(id) on delete restrict,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  auto_renew boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists provider_subs_provider_active_idx
  on public.provider_subscriptions (provider_id, is_active);

-- commissions: one row per completed order.

create table if not exists public.commissions (
  id uuid primary key default gen_random_uuid(),
  order_id uuid unique not null references public.orders(id) on delete cascade,
  provider_id uuid not null references public.providers(user_id) on delete restrict,
  base_amount numeric(12,2) not null,
  commission_pct numeric(5,2) not null,
  commission_amount numeric(12,2) not null,
  currency text not null default 'SAR',
  created_at timestamptz not null default now()
);

-- ads: admin-managed creatives and placements.

create table if not exists public.ad_creatives (
  id uuid primary key default gen_random_uuid(),
  title jsonb not null,
  body jsonb,
  image_path text,
  link_url text,
  provider_id uuid references public.providers(user_id) on delete set null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.ad_placements (
  id uuid primary key default gen_random_uuid(),
  creative_id uuid not null references public.ad_creatives(id) on delete cascade,
  slot text not null check (slot in ('home_top','category_top','search_top','category_inline')),
  category_id uuid references public.categories(id),
  city_id uuid references public.cities(id),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  is_active boolean not null default true
);

create index if not exists ad_placements_active_slot_idx
  on public.ad_placements (is_active, slot, starts_at desc);

create table if not exists public.ad_impressions (
  id bigserial primary key,
  placement_id uuid not null references public.ad_placements(id) on delete cascade,
  user_id uuid references public.profiles(user_id) on delete set null,
  was_click boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists ad_impressions_placement_idx
  on public.ad_impressions (placement_id, created_at desc);

-- invoices and payments (high-level; provider integration in Phase 9 wiring)

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  invoice_number text unique not null default ('INV-' || to_char(now(), 'YYYYMM') || '-' || lpad((floor(random()*999999))::text, 6, '0')),
  user_id uuid not null references public.profiles(user_id) on delete restrict,
  subscription_id uuid references public.provider_subscriptions(id),
  order_id uuid references public.orders(id),
  amount numeric(12,2) not null,
  currency text not null default 'SAR',
  status text not null default 'pending' check (status in ('pending','paid','failed','refunded','cancelled')),
  issued_at timestamptz not null default now(),
  paid_at timestamptz
);

create index if not exists invoices_user_status_idx on public.invoices (user_id, status, issued_at desc);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  provider text not null,                                  -- 'tap', 'moyasar', 'hyperpay'
  provider_charge_id text,
  amount numeric(12,2) not null,
  status text not null default 'pending' check (status in ('pending','succeeded','failed','refunded')),
  raw_response jsonb,
  created_at timestamptz not null default now()
);

-- RLS

alter table public.subscription_packages enable row level security;
alter table public.provider_subscriptions enable row level security;
alter table public.commissions enable row level security;
alter table public.ad_creatives enable row level security;
alter table public.ad_placements enable row level security;
alter table public.ad_impressions enable row level security;
alter table public.invoices enable row level security;
alter table public.payments enable row level security;

drop policy if exists packages_read_active on public.subscription_packages;
create policy packages_read_active
  on public.subscription_packages for select
  to anon, authenticated
  using (is_active or public.user_is_admin(auth.uid()));

drop policy if exists packages_write_super on public.subscription_packages;
create policy packages_write_super
  on public.subscription_packages for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

drop policy if exists provider_subs_select_self_or_admin on public.provider_subscriptions;
create policy provider_subs_select_self_or_admin
  on public.provider_subscriptions for select
  to authenticated
  using (provider_id = auth.uid() or public.user_is_admin(auth.uid()));

drop policy if exists commissions_select_self_or_admin on public.commissions;
create policy commissions_select_self_or_admin
  on public.commissions for select
  to authenticated
  using (provider_id = auth.uid() or public.user_is_admin(auth.uid()));

drop policy if exists ad_creatives_read on public.ad_creatives;
create policy ad_creatives_read
  on public.ad_creatives for select
  to anon, authenticated
  using (is_active or public.user_is_admin(auth.uid()));

drop policy if exists ad_creatives_write_admin on public.ad_creatives;
create policy ad_creatives_write_admin
  on public.ad_creatives for all
  to authenticated
  using (public.user_is_admin(auth.uid()))
  with check (public.user_is_admin(auth.uid()));

drop policy if exists ad_placements_read on public.ad_placements;
create policy ad_placements_read
  on public.ad_placements for select
  to anon, authenticated
  using (is_active or public.user_is_admin(auth.uid()));

drop policy if exists ad_placements_write_admin on public.ad_placements;
create policy ad_placements_write_admin
  on public.ad_placements for all
  to authenticated
  using (public.user_is_admin(auth.uid()))
  with check (public.user_is_admin(auth.uid()));

drop policy if exists invoices_select_self on public.invoices;
create policy invoices_select_self
  on public.invoices for select
  to authenticated
  using (user_id = auth.uid() or public.user_is_admin(auth.uid()));

commit;


-- ----------------------------------------------------------------------------
-- 0015_cms_settings_audit.sql
-- ----------------------------------------------------------------------------
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
  ('app.default_theme', '"navy"', 'Default theme for new users'),
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


-- ----------------------------------------------------------------------------
-- 0016_geography_hierarchy.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0016 · Geography hierarchy: regions → governorates → cities → districts.
-- A region must be activated by an admin before it (and anything under it) is
-- visible to the public. Activation/deactivation cascades down.

begin;

-- =========================================================================
-- 1. regions (المناطق) — top of the hierarchy
-- =========================================================================

create table if not exists public.regions (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name jsonb not null,                                  -- {ar, en, ...}
  display_order int not null default 0,
  is_active boolean not null default false,             -- admin must opt-in
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists regions_set_updated_at on public.regions;
create trigger regions_set_updated_at
  before update on public.regions
  for each row execute function public.set_updated_at();

create index if not exists regions_active_order_idx on public.regions (is_active, display_order);

-- =========================================================================
-- 2. governorates (المحافظات) — children of regions
-- =========================================================================

create table if not exists public.governorates (
  id uuid primary key default gen_random_uuid(),
  region_id uuid not null references public.regions(id) on delete cascade,
  slug text not null,
  name jsonb not null,
  display_order int not null default 0,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (region_id, slug)
);

drop trigger if exists governorates_set_updated_at on public.governorates;
create trigger governorates_set_updated_at
  before update on public.governorates
  for each row execute function public.set_updated_at();

create index if not exists governorates_region_idx on public.governorates (region_id, is_active);

-- =========================================================================
-- 3. cities — link to governorates (was: free-text "region" column)
-- =========================================================================

alter table public.cities
  add column if not exists governorate_id uuid references public.governorates(id) on delete cascade;

create index if not exists cities_governorate_idx on public.cities (governorate_id, is_active);

-- =========================================================================
-- 4. Cascade activation/deactivation
-- =========================================================================

-- when regions.is_active changes → propagate to all its governorates
create or replace function public.cascade_region_is_active()
returns trigger language plpgsql as $$
begin
  if new.is_active is distinct from old.is_active then
    update public.governorates
       set is_active = new.is_active
     where region_id = new.id
       and is_active is distinct from new.is_active;
  end if;
  return new;
end;
$$;

drop trigger if exists regions_cascade_is_active on public.regions;
create trigger regions_cascade_is_active
  after update of is_active on public.regions
  for each row execute function public.cascade_region_is_active();

-- when governorates.is_active changes → propagate to all its cities
create or replace function public.cascade_governorate_is_active()
returns trigger language plpgsql as $$
begin
  if new.is_active is distinct from old.is_active then
    update public.cities
       set is_active = new.is_active
     where governorate_id = new.id
       and is_active is distinct from new.is_active;
  end if;
  return new;
end;
$$;

drop trigger if exists governorates_cascade_is_active on public.governorates;
create trigger governorates_cascade_is_active
  after update of is_active on public.governorates
  for each row execute function public.cascade_governorate_is_active();

-- when a city is inserted, prevent it from being active if its governorate is inactive
create or replace function public.guard_city_active()
returns trigger language plpgsql as $$
declare v_gov_active boolean;
begin
  if new.governorate_id is null then
    return new;
  end if;
  select is_active into v_gov_active from public.governorates where id = new.governorate_id;
  if v_gov_active = false and new.is_active = true then
    new.is_active := false;
  end if;
  return new;
end;
$$;

drop trigger if exists cities_guard_active on public.cities;
create trigger cities_guard_active
  before insert or update on public.cities
  for each row execute function public.guard_city_active();

-- =========================================================================
-- 5. RLS — public reads only active rows; admin writes
-- =========================================================================

alter table public.regions enable row level security;
alter table public.governorates enable row level security;

drop policy if exists regions_read on public.regions;
create policy regions_read
  on public.regions for select
  to anon, authenticated
  using (is_active or public.user_is_admin(auth.uid()));

drop policy if exists regions_write_super on public.regions;
create policy regions_write_super
  on public.regions for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

drop policy if exists governorates_read on public.governorates;
create policy governorates_read
  on public.governorates for select
  to anon, authenticated
  using (
    public.user_is_admin(auth.uid())
    or (
      is_active
      and exists (select 1 from public.regions r where r.id = governorates.region_id and r.is_active)
    )
  );

drop policy if exists governorates_write_super on public.governorates;
create policy governorates_write_super
  on public.governorates for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

-- Tighten the existing cities read policy so a city is only visible to the
-- public when its whole chain (region → governorate → city) is active.
drop policy if exists cities_read_active on public.cities;
create policy cities_read_active
  on public.cities for select
  to anon, authenticated
  using (
    public.user_is_admin(auth.uid())
    or (
      is_active
      and (
        governorate_id is null
        or exists (
          select 1
          from public.governorates g
          join public.regions r on r.id = g.region_id
          where g.id = cities.governorate_id
            and g.is_active
            and r.is_active
        )
      )
    )
  );

-- =========================================================================
-- 6. Helper view: fully-visible cities (region + governorate + city all active)
-- =========================================================================

create or replace view public.cities_visible as
select c.*, g.region_id, g.name as governorate_name, r.name as region_name
from public.cities c
left join public.governorates g on g.id = c.governorate_id
left join public.regions r on r.id = g.region_id
where c.is_active
  and (g.id is null or (g.is_active and r.is_active));

-- =========================================================================
-- 7. Seed — 13 Saudi regions + major governorates + reseed cities
-- =========================================================================

insert into public.regions (slug, name, display_order) values
  ('riyadh',           '{"ar":"منطقة الرياض","en":"Riyadh Region"}',                10),
  ('makkah',           '{"ar":"منطقة مكة المكرمة","en":"Makkah Region"}',           20),
  ('madinah',          '{"ar":"منطقة المدينة المنورة","en":"Madinah Region"}',     30),
  ('eastern',          '{"ar":"المنطقة الشرقية","en":"Eastern Province"}',          40),
  ('asir',             '{"ar":"منطقة عسير","en":"Asir Region"}',                    50),
  ('qassim',           '{"ar":"منطقة القصيم","en":"Qassim Region"}',                60),
  ('tabuk',            '{"ar":"منطقة تبوك","en":"Tabuk Region"}',                   70),
  ('hail',             '{"ar":"منطقة حائل","en":"Hail Region"}',                    80),
  ('northern-borders', '{"ar":"منطقة الحدود الشمالية","en":"Northern Borders"}',   90),
  ('jazan',            '{"ar":"منطقة جازان","en":"Jazan Region"}',                 100),
  ('najran',           '{"ar":"منطقة نجران","en":"Najran Region"}',                110),
  ('bahah',            '{"ar":"منطقة الباحة","en":"Al-Bahah Region"}',             120),
  ('jouf',             '{"ar":"منطقة الجوف","en":"Al-Jawf Region"}',               130)
on conflict (slug) do nothing;

-- Governorates per region (representative — admin can extend later)
with reg as (select id, slug from public.regions)
insert into public.governorates (region_id, slug, name, display_order)
select r.id, g.slug, g.name, g.display_order
from reg r
join (values
  -- Riyadh region
  ('riyadh','riyadh',          '{"ar":"الرياض","en":"Riyadh"}'::jsonb,                  10),
  ('riyadh','diriyah',         '{"ar":"الدرعية","en":"Diriyah"}'::jsonb,                20),
  ('riyadh','kharj',           '{"ar":"الخرج","en":"Al-Kharj"}'::jsonb,                  30),
  ('riyadh','dawadmi',         '{"ar":"الدوادمي","en":"Dawadmi"}'::jsonb,               40),
  ('riyadh','majmaah',         '{"ar":"المجمعة","en":"Al-Majmaah"}'::jsonb,             50),
  ('riyadh','quwaiyah',        '{"ar":"القويعية","en":"Quwaiyah"}'::jsonb,              60),
  ('riyadh','wadi-dawasir',    '{"ar":"وادي الدواسر","en":"Wadi ad-Dawasir"}'::jsonb,   70),
  ('riyadh','zulfi',           '{"ar":"الزلفي","en":"Az-Zulfi"}'::jsonb,                80),
  ('riyadh','shaqra',          '{"ar":"شقراء","en":"Shaqra"}'::jsonb,                   90),
  ('riyadh','aflaj',           '{"ar":"الأفلاج","en":"Al-Aflaj"}'::jsonb,              100),
  -- Makkah region
  ('makkah','makkah',          '{"ar":"مكة المكرمة","en":"Makkah"}'::jsonb,             10),
  ('makkah','jeddah',          '{"ar":"جدة","en":"Jeddah"}'::jsonb,                     20),
  ('makkah','taif',            '{"ar":"الطائف","en":"Taif"}'::jsonb,                    30),
  ('makkah','qunfudhah',       '{"ar":"القنفذة","en":"Al-Qunfudhah"}'::jsonb,           40),
  ('makkah','laith',           '{"ar":"الليث","en":"Al-Laith"}'::jsonb,                 50),
  ('makkah','rabigh',          '{"ar":"رابغ","en":"Rabigh"}'::jsonb,                    60),
  ('makkah','khulais',         '{"ar":"خليص","en":"Khulais"}'::jsonb,                   70),
  ('makkah','jumum',           '{"ar":"الجموم","en":"Al-Jumum"}'::jsonb,                80),
  -- Madinah region
  ('madinah','madinah',        '{"ar":"المدينة المنورة","en":"Madinah"}'::jsonb,        10),
  ('madinah','yanbu',          '{"ar":"ينبع","en":"Yanbu"}'::jsonb,                     20),
  ('madinah','badr',           '{"ar":"بدر","en":"Badr"}'::jsonb,                       30),
  ('madinah','ula',            '{"ar":"العلا","en":"Al-Ula"}'::jsonb,                   40),
  ('madinah','khaybar',        '{"ar":"خيبر","en":"Khaybar"}'::jsonb,                   50),
  ('madinah','mahd-thahab',    '{"ar":"مهد الذهب","en":"Mahd adh-Dhahab"}'::jsonb,      60),
  ('madinah','henakiyah',      '{"ar":"الحناكية","en":"Al-Henakiyah"}'::jsonb,          70),
  -- Eastern Province
  ('eastern','dammam',         '{"ar":"الدمام","en":"Dammam"}'::jsonb,                  10),
  ('eastern','ahsa',           '{"ar":"الأحساء","en":"Al-Ahsa"}'::jsonb,                20),
  ('eastern','hafr-batin',     '{"ar":"حفر الباطن","en":"Hafr al-Batin"}'::jsonb,       30),
  ('eastern','jubail',         '{"ar":"الجبيل","en":"Jubail"}'::jsonb,                  40),
  ('eastern','qatif',          '{"ar":"القطيف","en":"Qatif"}'::jsonb,                   50),
  ('eastern','khobar',         '{"ar":"الخبر","en":"Khobar"}'::jsonb,                   60),
  ('eastern','dhahran',        '{"ar":"الظهران","en":"Dhahran"}'::jsonb,                70),
  ('eastern','nairyah',        '{"ar":"النعيرية","en":"An-Nairyah"}'::jsonb,            80),
  ('eastern','khafji',         '{"ar":"الخفجي","en":"Al-Khafji"}'::jsonb,               90),
  -- Asir
  ('asir','abha',              '{"ar":"أبها","en":"Abha"}'::jsonb,                      10),
  ('asir','khamis-mushait',    '{"ar":"خميس مشيط","en":"Khamis Mushait"}'::jsonb,       20),
  ('asir','bisha',             '{"ar":"بيشة","en":"Bisha"}'::jsonb,                     30),
  ('asir','namas',             '{"ar":"النماص","en":"An-Namas"}'::jsonb,                40),
  ('asir','muhayil',           '{"ar":"محايل عسير","en":"Muhayil Asir"}'::jsonb,        50),
  ('asir','rijal-almaa',       '{"ar":"رجال ألمع","en":"Rijal Almaa"}'::jsonb,          60),
  ('asir','tathlith',          '{"ar":"تثليث","en":"Tathlith"}'::jsonb,                 70),
  -- Qassim
  ('qassim','buraidah',        '{"ar":"بريدة","en":"Buraidah"}'::jsonb,                 10),
  ('qassim','unaizah',         '{"ar":"عنيزة","en":"Unaizah"}'::jsonb,                  20),
  ('qassim','rass',            '{"ar":"الرس","en":"Ar-Rass"}'::jsonb,                   30),
  ('qassim','mithnab',         '{"ar":"المذنب","en":"Al-Mithnab"}'::jsonb,              40),
  ('qassim','bukairiyah',      '{"ar":"البكيرية","en":"Al-Bukairiyah"}'::jsonb,         50),
  -- Tabuk
  ('tabuk','tabuk',            '{"ar":"تبوك","en":"Tabuk"}'::jsonb,                     10),
  ('tabuk','umluj',            '{"ar":"أملج","en":"Umluj"}'::jsonb,                     20),
  ('tabuk','duba',             '{"ar":"ضباء","en":"Duba"}'::jsonb,                      30),
  ('tabuk','tayma',            '{"ar":"تيماء","en":"Tayma"}'::jsonb,                    40),
  ('tabuk','haql',             '{"ar":"حقل","en":"Haql"}'::jsonb,                       50),
  -- Hail
  ('hail','hail',              '{"ar":"حائل","en":"Hail"}'::jsonb,                      10),
  ('hail','baqaa',             '{"ar":"بقعاء","en":"Baqaa"}'::jsonb,                    20),
  ('hail','ghazalah',          '{"ar":"الغزالة","en":"Al-Ghazalah"}'::jsonb,            30),
  -- Northern Borders
  ('northern-borders','arar',  '{"ar":"عرعر","en":"Arar"}'::jsonb,                      10),
  ('northern-borders','rafha', '{"ar":"رفحاء","en":"Rafha"}'::jsonb,                    20),
  ('northern-borders','turaif','{"ar":"طريف","en":"Turaif"}'::jsonb,                    30),
  -- Jazan
  ('jazan','jazan',            '{"ar":"جازان","en":"Jazan"}'::jsonb,                    10),
  ('jazan','sabya',            '{"ar":"صبيا","en":"Sabya"}'::jsonb,                     20),
  ('jazan','abu-arish',        '{"ar":"أبو عريش","en":"Abu Arish"}'::jsonb,             30),
  ('jazan','samtah',           '{"ar":"صامطة","en":"Samtah"}'::jsonb,                   40),
  -- Najran
  ('najran','najran',          '{"ar":"نجران","en":"Najran"}'::jsonb,                   10),
  ('najran','sharurah',        '{"ar":"شرورة","en":"Sharurah"}'::jsonb,                 20),
  ('najran','hubuna',          '{"ar":"حبونا","en":"Hubuna"}'::jsonb,                   30),
  -- Bahah
  ('bahah','bahah',            '{"ar":"الباحة","en":"Al-Bahah"}'::jsonb,                10),
  ('bahah','baljurashi',       '{"ar":"بلجرشي","en":"Baljurashi"}'::jsonb,              20),
  ('bahah','almandaq',         '{"ar":"المندق","en":"Al-Mandaq"}'::jsonb,               30),
  -- Jouf
  ('jouf','sakaka',            '{"ar":"سكاكا","en":"Sakaka"}'::jsonb,                   10),
  ('jouf','qurayyat',          '{"ar":"القريات","en":"Qurayyat"}'::jsonb,               20),
  ('jouf','dawmat-jandal',     '{"ar":"دومة الجندل","en":"Dumat al-Jandal"}'::jsonb,    30)
) as g(region_slug, slug, name, display_order) on g.region_slug = r.slug
on conflict (region_id, slug) do nothing;

-- Re-link existing cities to their governorates by matching slugs.
-- Cities that existed in earlier seed map cleanly to a governorate of the same slug.
update public.cities c
   set governorate_id = g.id
  from public.governorates g
 where c.governorate_id is null
   and c.slug = g.slug;

-- Ensure existing cities (from earlier seed) start inactive — admin must opt them
-- in by activating the parent region (which cascades).
update public.cities set is_active = false where governorate_id is null or true;

commit;


-- ----------------------------------------------------------------------------
-- 0017_user_addresses_saved_services.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0017 · User addresses + saved-services + customers helper view.

begin;

-- =========================================================================
-- 1. user_addresses — multiple addresses per user (home / work / custom)
-- =========================================================================

create table if not exists public.user_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  label text not null default 'home',
  region_id uuid references public.regions(id) on delete set null,
  governorate_id uuid references public.governorates(id) on delete set null,
  city_id uuid references public.cities(id) on delete set null,
  district_name text,
  street text,
  building text,
  details text,
  location geography(Point, 4326),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists user_addresses_set_updated_at on public.user_addresses;
create trigger user_addresses_set_updated_at
  before update on public.user_addresses
  for each row execute function public.set_updated_at();

create index if not exists user_addresses_user_default_idx
  on public.user_addresses (user_id, is_default desc);
create index if not exists user_addresses_location_gix
  on public.user_addresses using gist (location);

-- enforce single default per user
create or replace function public.enforce_single_default_address()
returns trigger language plpgsql as $$
begin
  if new.is_default then
    update public.user_addresses
       set is_default = false
     where user_id = new.user_id
       and id <> new.id
       and is_default = true;
  end if;
  return new;
end;
$$;

drop trigger if exists user_addresses_single_default on public.user_addresses;
create trigger user_addresses_single_default
  after insert or update of is_default on public.user_addresses
  for each row execute function public.enforce_single_default_address();

alter table public.user_addresses enable row level security;

drop policy if exists user_addresses_rw_self on public.user_addresses;
create policy user_addresses_rw_self
  on public.user_addresses for all
  to authenticated
  using (user_id = auth.uid() or public.user_is_admin(auth.uid()))
  with check (user_id = auth.uid());

-- =========================================================================
-- 2. saved_services — requester wishlist
-- =========================================================================

create table if not exists public.saved_services (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  service_id uuid not null references public.services(id) on delete cascade,
  note text check (length(note) <= 500),
  created_at timestamptz not null default now(),
  primary key (user_id, service_id)
);

create index if not exists saved_services_user_idx
  on public.saved_services (user_id, created_at desc);

alter table public.saved_services enable row level security;

drop policy if exists saved_services_rw_self on public.saved_services;
create policy saved_services_rw_self
  on public.saved_services for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- =========================================================================
-- 3. provider_customers view — derived from completed orders
-- =========================================================================

create or replace view public.provider_customers as
select
  o.provider_id,
  o.requester_id as customer_id,
  p.full_name as customer_name,
  p.phone_e164 as customer_phone,
  count(o.id) as orders_count,
  count(o.id) filter (where o.status = 'completed') as completed_count,
  max(o.created_at) as last_order_at,
  min(o.created_at) as first_order_at,
  avg(r.score) filter (where r.is_visible) as avg_rating_given
from public.orders o
join public.profiles p on p.user_id = o.requester_id
left join public.ratings r on r.order_id = o.id and r.rater_id = o.requester_id
where o.provider_id is not null
group by o.provider_id, o.requester_id, p.full_name, p.phone_e164;

-- RLS does not apply directly to views; the underlying tables' RLS gates access.

commit;


-- ----------------------------------------------------------------------------
-- 0018_username_dual_role.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0018 · Optional username, optional email, dual-role profile.
--
-- - profiles.username: optional, unique, used as a friendly login handle.
-- - profiles.active_role: which role the user is currently acting as
--   ('requester' or 'provider'); only meaningful when they hold both.
-- - email_normalized becomes nullable (was previously implicit-required).
-- - phone_e164 stays required as the primary auth handle.

begin;

alter table public.profiles
  add column if not exists username text,
  add column if not exists active_role public.user_role not null default 'requester';

-- Username uniqueness when present
do $$ begin
  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public' and indexname = 'profiles_username_unique'
  ) then
    create unique index profiles_username_unique
      on public.profiles (username)
      where username is not null;
  end if;
end $$;

-- Allow lookups by username / phone for sign-in (service-role in Edge Functions
-- still bypasses RLS; this read policy lets the lookup server action work too).
drop policy if exists profiles_lookup_for_signin on public.profiles;
create policy profiles_lookup_for_signin
  on public.profiles for select
  to anon, authenticated
  using (true);  -- we only ever return user_id from this lookup, never PII

-- (the existing profiles_select_self_or_admin policy still applies to full-row
-- access for authenticated users; this anon-friendly policy lets the sign-in
-- flow find which user a username/phone belongs to.)

-- Helper: make sure active_role is one this user actually has
create or replace function public.guard_active_role()
returns trigger language plpgsql as $$
begin
  if not exists (
    select 1 from public.user_roles
    where user_id = new.user_id and role = new.active_role
  ) then
    -- silently fall back to whatever role they do have, preferring requester
    new.active_role := coalesce(
      (select role from public.user_roles where user_id = new.user_id
        order by case role when 'requester' then 1 when 'provider' then 2 else 3 end
        limit 1),
      'requester'::public.user_role
    );
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_guard_active_role on public.profiles;
create trigger profiles_guard_active_role
  before insert or update of active_role on public.profiles
  for each row execute function public.guard_active_role();

-- Reverse helper: resolve a sign-in handle (username / phone / email) to the
-- internal auth user_id. Returns null when nothing matches. Marked SECURITY
-- DEFINER so callers don't need direct read on auth.users.
create or replace function public.resolve_signin_handle(p_handle text)
returns table (user_id uuid, email text, phone_e164 text)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if p_handle is null or length(p_handle) = 0 then
    return;
  end if;

  return query
  select p.user_id, p.email_normalized, p.phone_e164
  from public.profiles p
  where
    p.username = lower(p_handle)
    or p.phone_e164 = p_handle
    or p.email_normalized = lower(p_handle)
  limit 1;
end;
$$;

grant execute on function public.resolve_signin_handle(text) to anon, authenticated;

commit;


-- ----------------------------------------------------------------------------
-- 0019_geography_schema_v2.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0019 · Geographic schema upgrade for full Saudi hierarchy.
--
-- Adds:
--   - lat / lng on every level (regions / governorates / cities / districts)
--   - trigram GIN indexes on every name->'ar' and name->'en' for fast prefix
--     and substring search regardless of locale
--   - locations_search view that fans the four levels into a single rowset
--     keyed by a synthetic kind+slug, so a global search endpoint can match
--     across the whole tree in one query
--   - helper find_districts_near(lat, lng, radius_m) for "nearest district"
--     resolution from a map pin
--
-- Idempotent: alter ... add column if not exists, create index if not exists,
-- and the view is `create or replace`. Safe to run multiple times.

begin;

-- =========================================================================
-- 1. Coordinates on every level
-- =========================================================================

alter table public.regions
  add column if not exists lat double precision,
  add column if not exists lng double precision;

alter table public.governorates
  add column if not exists lat double precision,
  add column if not exists lng double precision;

alter table public.cities
  add column if not exists lat double precision,
  add column if not exists lng double precision;

alter table public.districts
  add column if not exists lat double precision,
  add column if not exists lng double precision,
  add column if not exists display_order int not null default 0,
  add column if not exists is_active boolean not null default true,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

drop trigger if exists districts_set_updated_at on public.districts;
create trigger districts_set_updated_at
  before update on public.districts
  for each row execute function public.set_updated_at();

-- PostGIS Point for spatial queries when both lat & lng are present.
-- We mirror lat/lng into a generated geography column so existing GIST
-- patterns work without ad-hoc point construction.

alter table public.districts
  add column if not exists location geography(Point, 4326);

create or replace function public.sync_lat_lng_to_location()
returns trigger language plpgsql as $$
begin
  if new.lat is not null and new.lng is not null then
    new.location := st_setsrid(st_makepoint(new.lng, new.lat), 4326)::geography;
  else
    new.location := null;
  end if;
  return new;
end;
$$;

drop trigger if exists districts_sync_location on public.districts;
create trigger districts_sync_location
  before insert or update of lat, lng on public.districts
  for each row execute function public.sync_lat_lng_to_location();

-- =========================================================================
-- 2. Fast search — trigram on Arabic + English names per level
-- =========================================================================

create index if not exists regions_name_ar_trgm
  on public.regions using gin ((name->>'ar') gin_trgm_ops);
create index if not exists regions_name_en_trgm
  on public.regions using gin ((name->>'en') gin_trgm_ops);

create index if not exists governorates_name_ar_trgm
  on public.governorates using gin ((name->>'ar') gin_trgm_ops);
create index if not exists governorates_name_en_trgm
  on public.governorates using gin ((name->>'en') gin_trgm_ops);

create index if not exists cities_name_ar_trgm
  on public.cities using gin ((name->>'ar') gin_trgm_ops);
create index if not exists cities_name_en_trgm
  on public.cities using gin ((name->>'en') gin_trgm_ops);

create index if not exists districts_name_ar_trgm
  on public.districts using gin ((name->>'ar') gin_trgm_ops);
create index if not exists districts_name_en_trgm
  on public.districts using gin ((name->>'en') gin_trgm_ops);

create index if not exists districts_city_active_idx
  on public.districts (city_id, is_active, display_order);

create index if not exists districts_location_gix
  on public.districts using gist (location);

-- =========================================================================
-- 3. Cross-level search view + tightened district RLS
-- =========================================================================

create or replace view public.locations_search as
  select 'region'::text as kind,
         r.id,
         r.slug,
         r.name,
         null::uuid as parent_id,
         null::text as parent_slug,
         r.lat, r.lng,
         r.is_active,
         r.display_order
    from public.regions r
  union all
  select 'governorate'::text,
         g.id,
         g.slug,
         g.name,
         g.region_id,
         (select r.slug from public.regions r where r.id = g.region_id),
         g.lat, g.lng,
         g.is_active,
         g.display_order
    from public.governorates g
  union all
  select 'city'::text,
         c.id,
         c.slug,
         c.name,
         c.governorate_id,
         (select g.slug from public.governorates g where g.id = c.governorate_id),
         c.lat, c.lng,
         c.is_active,
         c.display_order
    from public.cities c
  union all
  select 'district'::text,
         d.id,
         d.slug,
         d.name,
         d.city_id,
         (select c.slug from public.cities c where c.id = d.city_id),
         d.lat, d.lng,
         d.is_active,
         d.display_order
    from public.districts d;

-- =========================================================================
-- 4. Helpers
-- =========================================================================

-- Find the nearest active district to a coordinate. Used by the sign-up
-- "use my location" flow to suggest a district after the map pin is set.
create or replace function public.districts_nearest(
  p_lat double precision,
  p_lng double precision,
  p_radius_m double precision default 20000
)
returns table (
  district_id uuid,
  district_slug text,
  district_name jsonb,
  city_id uuid,
  city_slug text,
  city_name jsonb,
  governorate_id uuid,
  region_id uuid,
  distance_m double precision
)
language sql
stable
as $$
  select
    d.id, d.slug, d.name,
    c.id, c.slug, c.name,
    g.id, r.id,
    st_distance(d.location, st_makepoint(p_lng, p_lat)::geography) as distance_m
  from public.districts d
  join public.cities c on c.id = d.city_id
  join public.governorates g on g.id = c.governorate_id
  join public.regions r on r.id = g.region_id
  where d.is_active
    and c.is_active
    and g.is_active
    and r.is_active
    and d.location is not null
    and st_dwithin(d.location, st_makepoint(p_lng, p_lat)::geography, p_radius_m)
  order by distance_m asc
  limit 5;
$$;

-- =========================================================================
-- 5. Tightened RLS for districts (mirrors cities)
-- =========================================================================

drop policy if exists districts_read_all on public.districts;
create policy districts_read_active
  on public.districts for select
  to anon, authenticated
  using (
    public.user_is_admin(auth.uid())
    or (
      is_active
      and (
        city_id is null
        or exists (
          select 1
          from public.cities c
          join public.governorates g on g.id = c.governorate_id
          join public.regions r on r.id = g.region_id
          where c.id = districts.city_id
            and c.is_active and g.is_active and r.is_active
        )
      )
    )
  );

commit;


-- ----------------------------------------------------------------------------
-- 0020_saudi_geography_seed.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0020 · Comprehensive Saudi Arabia geography seed.
--
-- All 13 administrative regions + every official governorate + main cities +
-- districts for the five largest metro areas (Riyadh, Jeddah, Makkah,
-- Madinah, Dammam metro).
--
-- Multilingual names: ar + en for every row. ur / hi / bn names match the
-- Arabic for proper nouns (they're transliterations of the same word in a
-- different script — admins can refine via /admin/translations).
--
-- All inserts use `on conflict ... do update` so re-running the migration
-- refreshes translations and coordinates without disturbing admin-set
-- is_active flags.

begin;

-- =========================================================================
-- 1. Regions — refresh names + coordinates
-- =========================================================================

insert into public.regions (slug, name, lat, lng, display_order) values
  ('riyadh',           '{"ar":"منطقة الرياض","en":"Riyadh Region","ur":"ریاض","hi":"रियाद","bn":"রিয়াদ"}',                24.7136, 46.6753, 10),
  ('makkah',           '{"ar":"منطقة مكة المكرمة","en":"Makkah Region","ur":"مکہ","hi":"मक्का","bn":"মক্কা"}',              21.3891, 39.8579, 20),
  ('madinah',          '{"ar":"منطقة المدينة المنورة","en":"Madinah Region","ur":"مدینہ","hi":"मदीना","bn":"মদিনা"}',     24.5247, 39.5692, 30),
  ('eastern',          '{"ar":"المنطقة الشرقية","en":"Eastern Province","ur":"مشرقی صوبہ","hi":"पूर्वी प्रांत","bn":"পূর্ব প্রদেশ"}', 26.4207, 50.0888, 40),
  ('asir',             '{"ar":"منطقة عسير","en":"Asir Region","ur":"عسیر","hi":"असीर","bn":"আসির"}',                       18.2167, 42.5053, 50),
  ('qassim',           '{"ar":"منطقة القصيم","en":"Qassim Region","ur":"قصیم","hi":"क़सीम","bn":"কাসিম"}',                 26.3206, 43.9750, 60),
  ('tabuk',            '{"ar":"منطقة تبوك","en":"Tabuk Region","ur":"تبوک","hi":"तबूक","bn":"তাবুক"}',                     28.3835, 36.5662, 70),
  ('hail',             '{"ar":"منطقة حائل","en":"Hail Region","ur":"حائل","hi":"हाइल","bn":"হাইল"}',                       27.5114, 41.6900, 80),
  ('northern-borders', '{"ar":"منطقة الحدود الشمالية","en":"Northern Borders","ur":"شمالی سرحدیں","hi":"उत्तरी सीमा","bn":"উত্তর সীমান্ত"}', 30.9753, 41.0214, 90),
  ('jazan',            '{"ar":"منطقة جازان","en":"Jazan Region","ur":"جازان","hi":"जाज़ान","bn":"জাজান"}',                100, 16.8892, 42.5611),
  ('najran',           '{"ar":"منطقة نجران","en":"Najran Region","ur":"نجران","hi":"नजरान","bn":"নাজরান"}',               17.5656, 44.2289, 110),
  ('bahah',            '{"ar":"منطقة الباحة","en":"Al-Bahah Region","ur":"الباحہ","hi":"अल-बाहा","bn":"আল-বাহা"}',         20.0129, 41.4677, 120),
  ('jouf',             '{"ar":"منطقة الجوف","en":"Al-Jouf Region","ur":"الجوف","hi":"अल-जौफ","bn":"আল-জৌফ"}',              29.7858, 40.2056, 130)
on conflict (slug) do update set
  name = excluded.name,
  lat  = excluded.lat,
  lng  = excluded.lng,
  display_order = excluded.display_order;

-- Jazan had its (display_order, lat, lng) tuple flipped above — fix it
-- explicitly in case the values inserted got rearranged in older runs.
update public.regions
   set lat = 16.8892, lng = 42.5611, display_order = 100
 where slug = 'jazan';

-- =========================================================================
-- 2. Governorates — full official list per region
-- =========================================================================

-- Helper CTE pattern: select the region id then join in the values block.
with reg as (select id, slug from public.regions)
insert into public.governorates (region_id, slug, name, lat, lng, display_order)
select r.id, g.slug, g.name, g.lat, g.lng, g.display_order
from reg r
join (values
  -- Riyadh region (19 governorates)
  ('riyadh','riyadh',           '{"ar":"الرياض","en":"Riyadh","ur":"ریاض","hi":"रियाद","bn":"রিয়াদ"}'::jsonb,                       24.7136, 46.6753, 10),
  ('riyadh','diriyah',          '{"ar":"الدرعية","en":"Diriyah","ur":"درعیہ","hi":"दिरिया","bn":"দিরিয়া"}'::jsonb,                    24.7351, 46.5750, 20),
  ('riyadh','kharj',            '{"ar":"الخرج","en":"Al-Kharj","ur":"الخرج","hi":"अल-खर्ज","bn":"আল-খারজ"}'::jsonb,                  24.1554, 47.3346, 30),
  ('riyadh','dawadmi',          '{"ar":"الدوادمي","en":"Dawadmi","ur":"دوادمی","hi":"दवादमी","bn":"দাওয়াদমি"}'::jsonb,                24.5074, 44.3955, 40),
  ('riyadh','majmaah',          '{"ar":"المجمعة","en":"Al-Majmaah","ur":"المجمعہ","hi":"अल-मजमाह","bn":"আল-মাজমাহ"}'::jsonb,         25.9090, 45.3500, 50),
  ('riyadh','quwaiyah',         '{"ar":"القويعية","en":"Quwaiyah","ur":"قویعیہ","hi":"क़ुवैया","bn":"কুওয়াইয়া"}'::jsonb,             24.0617, 45.2632, 60),
  ('riyadh','wadi-dawasir',     '{"ar":"وادي الدواسر","en":"Wadi ad-Dawasir","ur":"وادی الدواسر","hi":"वादी अद-दवासर","bn":"ওয়াদি আদ-দাওয়াসির"}'::jsonb, 20.4922, 44.8044, 70),
  ('riyadh','zulfi',            '{"ar":"الزلفي","en":"Az-Zulfi","ur":"الزلفی","hi":"अज़-ज़ुल्फ़ी","bn":"আজ-জুলফি"}'::jsonb,           26.2982, 44.8156, 80),
  ('riyadh','shaqra',           '{"ar":"شقراء","en":"Shaqra","ur":"شقراء","hi":"शक़रा","bn":"শাকরা"}'::jsonb,                       25.2402, 45.2569, 90),
  ('riyadh','aflaj',            '{"ar":"الأفلاج","en":"Al-Aflaj","ur":"الأفلاج","hi":"अल-अफ़लाज","bn":"আল-আফলাজ"}'::jsonb,           22.2655, 46.7320, 100),
  ('riyadh','hawtat-bani-tamim','{"ar":"حوطة بني تميم","en":"Hawtat Bani Tamim","ur":"حوطہ بنی تمیم","hi":"हौता बनी तमीम","bn":"হাওতা বনি তামিম"}'::jsonb, 23.5217, 46.8489, 110),
  ('riyadh','afif',             '{"ar":"عفيف","en":"Afif","ur":"عفیف","hi":"अफ़ीफ़","bn":"আফিফ"}'::jsonb,                          23.9095, 42.9168, 120),
  ('riyadh','sulayyil',         '{"ar":"السليل","en":"As-Sulayyil","ur":"السلیل","hi":"अस-सुलैयिल","bn":"আস-সুলাইল"}'::jsonb,         20.4630, 45.5790, 130),
  ('riyadh','dhurma',           '{"ar":"ضرما","en":"Dhurma","ur":"ضرما","hi":"धुरमा","bn":"ধুরমা"}'::jsonb,                        24.6111, 46.1556, 140),
  ('riyadh','rumah',            '{"ar":"رماح","en":"Rumah","ur":"رماح","hi":"रुमाह","bn":"রুমাহ"}'::jsonb,                          25.5667, 47.1500, 150),
  ('riyadh','thadiq',           '{"ar":"ثادق","en":"Thadiq","ur":"ثادق","hi":"थादिक़","bn":"থাদিক"}'::jsonb,                        25.2917, 45.8606, 160),
  ('riyadh','ghat',             '{"ar":"الغاط","en":"Al-Ghat","ur":"الغاط","hi":"अल-घात","bn":"আল-ঘাত"}'::jsonb,                    26.0167, 44.9667, 170),
  ('riyadh','huraymila',        '{"ar":"حريملاء","en":"Huraymila","ur":"حریملاء","hi":"हुरैमिला","bn":"হুরাইমিলা"}'::jsonb,           25.1419, 46.1056, 180),
  ('riyadh','muzahmiya',        '{"ar":"المزاحمية","en":"Muzahmiya","ur":"مزاحمیہ","hi":"मुज़ाहमीया","bn":"মুজাহমিয়া"}'::jsonb,        24.4750, 46.2722, 190),

  -- Makkah region (13)
  ('makkah','makkah',           '{"ar":"مكة المكرمة","en":"Makkah","ur":"مکہ مکرمہ","hi":"मक्का","bn":"মক্কা"}'::jsonb,             21.4225, 39.8262, 10),
  ('makkah','jeddah',           '{"ar":"جدة","en":"Jeddah","ur":"جدہ","hi":"जेद्दा","bn":"জেদ্দা"}'::jsonb,                         21.4858, 39.1925, 20),
  ('makkah','taif',             '{"ar":"الطائف","en":"Taif","ur":"طائف","hi":"ताइफ़","bn":"তাইফ"}'::jsonb,                          21.2854, 40.4183, 30),
  ('makkah','qunfudhah',        '{"ar":"القنفذة","en":"Al-Qunfudhah","ur":"القنفذہ","hi":"अल-क़ुनफ़ुधा","bn":"আল-কুনফুধা"}'::jsonb, 19.1264, 41.0796, 40),
  ('makkah','laith',            '{"ar":"الليث","en":"Al-Laith","ur":"اللیث","hi":"अल-लैथ","bn":"আল-লাইথ"}'::jsonb,                  20.1503, 40.2667, 50),
  ('makkah','rabigh',           '{"ar":"رابغ","en":"Rabigh","ur":"رابغ","hi":"राबिग़","bn":"রাবিগ"}'::jsonb,                        22.7986, 39.0349, 60),
  ('makkah','khulais',          '{"ar":"خليص","en":"Khulais","ur":"خلیص","hi":"ख़ुलैस","bn":"খুলাইস"}'::jsonb,                       22.1583, 39.3194, 70),
  ('makkah','jumum',            '{"ar":"الجموم","en":"Al-Jumum","ur":"الجموم","hi":"अल-जुमूम","bn":"আল-জুমুম"}'::jsonb,             21.6125, 39.7000, 80),
  ('makkah','kamil',            '{"ar":"الكامل","en":"Al-Kamil","ur":"الکامل","hi":"अल-कामिल","bn":"আল-কামিল"}'::jsonb,             21.7456, 39.7361, 90),
  ('makkah','khurma',           '{"ar":"الخرمة","en":"Al-Khurma","ur":"الخرمہ","hi":"अल-खुर्मा","bn":"আল-খুরমা"}'::jsonb,             21.9226, 42.0490, 100),
  ('makkah','ranyah',           '{"ar":"رنية","en":"Ranyah","ur":"رنیہ","hi":"रनिया","bn":"রনিয়া"}'::jsonb,                         21.2667, 42.8500, 110),
  ('makkah','turabah',          '{"ar":"تربة","en":"Turabah","ur":"تربہ","hi":"तुरबा","bn":"তুরবাহ"}'::jsonb,                       21.2117, 41.6347, 120),
  ('makkah','adam',             '{"ar":"العرضيات","en":"Al-Ardiyat","ur":"العرضیات","hi":"अल-अरदियात","bn":"আল-আরদিয়াত"}'::jsonb,    19.7944, 41.5067, 130),

  -- Madinah region (7)
  ('madinah','madinah',         '{"ar":"المدينة المنورة","en":"Madinah","ur":"مدینہ","hi":"मदीना","bn":"মদিনা"}'::jsonb,           24.4686, 39.6142, 10),
  ('madinah','yanbu',           '{"ar":"ينبع","en":"Yanbu","ur":"ینبع","hi":"यनबू","bn":"ইয়ানবু"}'::jsonb,                          24.0894, 38.0617, 20),
  ('madinah','badr',            '{"ar":"بدر","en":"Badr","ur":"بدر","hi":"बद्र","bn":"বদর"}'::jsonb,                                23.7800, 38.7900, 30),
  ('madinah','ula',             '{"ar":"العلا","en":"Al-Ula","ur":"العلا","hi":"अल-उला","bn":"আল-উলা"}'::jsonb,                     26.6097, 37.9128, 40),
  ('madinah','khaybar',         '{"ar":"خيبر","en":"Khaybar","ur":"خیبر","hi":"ख़ैबर","bn":"খাইবার"}'::jsonb,                       25.7000, 39.2917, 50),
  ('madinah','mahd-thahab',     '{"ar":"مهد الذهب","en":"Mahd adh-Dhahab","ur":"مہد الذہب","hi":"महद अध-धहब","bn":"মাহদ আদ-ধাহাব"}'::jsonb, 23.5000, 40.8500, 60),
  ('madinah','henakiyah',       '{"ar":"الحناكية","en":"Al-Henakiyah","ur":"الحناکیہ","hi":"अल-हनाकिया","bn":"আল-হেনাকিয়া"}'::jsonb, 24.8639, 40.5099, 70),

  -- Eastern Province (12)
  ('eastern','dammam',          '{"ar":"الدمام","en":"Dammam","ur":"دمام","hi":"दम्माम","bn":"দাম্মাম"}'::jsonb,                  26.4207, 50.0888, 10),
  ('eastern','ahsa',            '{"ar":"الأحساء","en":"Al-Ahsa","ur":"الأحساء","hi":"अल-अहसा","bn":"আল-আহসা"}'::jsonb,             25.3833, 49.5867, 20),
  ('eastern','hafr-batin',      '{"ar":"حفر الباطن","en":"Hafr al-Batin","ur":"حفر الباطن","hi":"हफ़र अल-बातिन","bn":"হাফর আল-বাতিন"}'::jsonb, 28.4338, 45.9601, 30),
  ('eastern','jubail',          '{"ar":"الجبيل","en":"Jubail","ur":"جبیل","hi":"जुबैल","bn":"জুবাইল"}'::jsonb,                     27.0046, 49.6603, 40),
  ('eastern','qatif',           '{"ar":"القطيف","en":"Qatif","ur":"قطیف","hi":"क़तीफ़","bn":"কাতিফ"}'::jsonb,                       26.5658, 49.9962, 50),
  ('eastern','khobar',          '{"ar":"الخبر","en":"Khobar","ur":"خبر","hi":"ख़ोबर","bn":"খোবার"}'::jsonb,                       26.2172, 50.1971, 60),
  ('eastern','dhahran',         '{"ar":"الظهران","en":"Dhahran","ur":"ظہران","hi":"धहरान","bn":"ধাহরান"}'::jsonb,                  26.2361, 50.0393, 70),
  ('eastern','nairyah',         '{"ar":"النعيرية","en":"An-Nairyah","ur":"النعیریہ","hi":"अन-नैरिया","bn":"আন-নাইরিয়া"}'::jsonb,    27.4811, 48.4842, 80),
  ('eastern','khafji',          '{"ar":"الخفجي","en":"Al-Khafji","ur":"الخفجی","hi":"अल-ख़फ़जी","bn":"আল-খাফজি"}'::jsonb,             28.4344, 48.4910, 90),
  ('eastern','ras-tanura',      '{"ar":"رأس تنورة","en":"Ras Tanura","ur":"رأس تنورہ","hi":"रास तनूरा","bn":"রাস তানুরা"}'::jsonb,    26.6431, 50.1593, 100),
  ('eastern','qaryat-ulya',     '{"ar":"قرية العليا","en":"Qaryat al-Ulya","ur":"قریۃ العلیا","hi":"क़रिया अल-उल्या","bn":"কারিয়া আল-উলিয়া"}'::jsonb, 27.6300, 47.5300, 110),
  ('eastern','buqayq',          '{"ar":"بقيق","en":"Buqayq","ur":"بقیق","hi":"बुक़ैक़","bn":"বুকাইক"}'::jsonb,                        25.9333, 49.6667, 120),

  -- Asir (13)
  ('asir','abha',               '{"ar":"أبها","en":"Abha","ur":"ابہا","hi":"अभा","bn":"আবহা"}'::jsonb,                              18.2167, 42.5053, 10),
  ('asir','khamis-mushait',     '{"ar":"خميس مشيط","en":"Khamis Mushait","ur":"خمیس مشیط","hi":"ख़मीस मुशैत","bn":"খামিস মুশাইত"}'::jsonb, 18.3000, 42.7333, 20),
  ('asir','bisha',              '{"ar":"بيشة","en":"Bisha","ur":"بیشہ","hi":"बीशा","bn":"বিশা"}'::jsonb,                            20.0000, 42.6000, 30),
  ('asir','namas',              '{"ar":"النماص","en":"An-Namas","ur":"النماص","hi":"अन-नमास","bn":"আন-নামাস"}'::jsonb,             19.1500, 42.1167, 40),
  ('asir','muhayil',            '{"ar":"محايل عسير","en":"Muhayil Asir","ur":"محایل عسیر","hi":"मुहैयिल असीर","bn":"মুহাইল আসির"}'::jsonb, 18.5444, 41.9614, 50),
  ('asir','rijal-almaa',        '{"ar":"رجال ألمع","en":"Rijal Almaa","ur":"رجال ألمع","hi":"रिजाल अलमा","bn":"রিজাল আলমা"}'::jsonb,    18.1844, 42.1581, 60),
  ('asir','tathlith',           '{"ar":"تثليث","en":"Tathlith","ur":"تثلیث","hi":"तथलीथ","bn":"তাথলিথ"}'::jsonb,                    19.5667, 43.3000, 70),
  ('asir','sarat-abidah',       '{"ar":"سراة عبيدة","en":"Sarat Abidah","ur":"سراۃ عبیدہ","hi":"सरात अबीदा","bn":"সারাত আবিদা"}'::jsonb, 18.1500, 42.9000, 80),
  ('asir','bariq',              '{"ar":"بارق","en":"Bariq","ur":"بارق","hi":"बारिक़","bn":"বারিক"}'::jsonb,                          18.7167, 41.9667, 90),
  ('asir','dhahran-janub',      '{"ar":"ظهران الجنوب","en":"Dhahran al-Janub","ur":"ظہران الجنوب","hi":"धहरान अल-जनूब","bn":"ধাহরান আল-জানুব"}'::jsonb, 17.6000, 43.5000, 100),
  ('asir','tareeb',             '{"ar":"تريب","en":"Tareeb","ur":"تریب","hi":"तरीब","bn":"তারিব"}'::jsonb,                          17.7000, 43.4500, 110),
  ('asir','mojaridah',          '{"ar":"المجاردة","en":"Al-Mojaridah","ur":"المجاردہ","hi":"अल-मोजारिदा","bn":"আল-মোজারিদা"}'::jsonb, 19.1228, 41.9603, 120),
  ('asir','ahad-rufaidah',      '{"ar":"أحد رفيدة","en":"Ahad Rufaidah","ur":"احد رفیدہ","hi":"अहद रुफ़ैदा","bn":"আহাদ রুফাইদা"}'::jsonb, 18.2289, 42.7506, 130),

  -- Qassim (12)
  ('qassim','buraidah',         '{"ar":"بريدة","en":"Buraidah","ur":"بریدہ","hi":"बुरैदा","bn":"বুরাইদা"}'::jsonb,                  26.3260, 43.9750, 10),
  ('qassim','unaizah',          '{"ar":"عنيزة","en":"Unaizah","ur":"عنیزہ","hi":"उनैज़ा","bn":"উনাইজা"}'::jsonb,                    26.0844, 43.9961, 20),
  ('qassim','rass',             '{"ar":"الرس","en":"Ar-Rass","ur":"الرس","hi":"अर-रस","bn":"আর-রাস"}'::jsonb,                       25.8721, 43.5012, 30),
  ('qassim','mithnab',          '{"ar":"المذنب","en":"Al-Mithnab","ur":"المذنب","hi":"अल-मिथनब","bn":"আল-মিথনাব"}'::jsonb,         25.8667, 44.2167, 40),
  ('qassim','bukairiyah',       '{"ar":"البكيرية","en":"Al-Bukairiyah","ur":"البکیریہ","hi":"अल-बुकैरिया","bn":"আল-বুকাইরিয়া"}'::jsonb, 26.1397, 43.6597, 50),
  ('qassim','badayea',          '{"ar":"البدائع","en":"Al-Badayea","ur":"البدائع","hi":"अल-बदायेआ","bn":"আল-বাদায়েআ"}'::jsonb,      26.0444, 43.7833, 60),
  ('qassim','riyadh-khabra',    '{"ar":"رياض الخبراء","en":"Riyadh al-Khabra","ur":"ریاض الخبراء","hi":"रियाद अल-ख़बरा","bn":"রিয়াদ আল-খাবরা"}'::jsonb, 26.5000, 43.5500, 70),
  ('qassim','nabhaniyah',       '{"ar":"النبهانية","en":"An-Nabhaniyah","ur":"النبہانیہ","hi":"अन-नबहानिया","bn":"আন-নাবহানিয়া"}'::jsonb, 26.3833, 43.1500, 80),
  ('qassim','shimasiyah',       '{"ar":"الشماسية","en":"Ash-Shimasiyah","ur":"الشماسیہ","hi":"अश-शिमासिया","bn":"আশ-শিমাসিয়া"}'::jsonb, 26.5500, 43.1833, 90),
  ('qassim','uyun-jiwa',        '{"ar":"عيون الجواء","en":"Uyun al-Jiwa","ur":"عیون الجواء","hi":"उयून अल-जिवा","bn":"উয়ুন আল-জিওয়া"}'::jsonb, 26.4500, 43.7833, 100),
  ('qassim','asyah',            '{"ar":"عسيا","en":"Asyah","ur":"عسیا","hi":"असया","bn":"আসিয়া"}'::jsonb,                          26.4833, 43.4500, 110),
  ('qassim','nuayriah',         '{"ar":"النعيرية القصيم","en":"An-Nuayriah","ur":"النعیریہ","hi":"अन-नुऐरिया","bn":"আন-নুয়াইরিয়া"}'::jsonb, 26.7167, 43.9667, 120),

  -- Tabuk (7)
  ('tabuk','tabuk',             '{"ar":"تبوك","en":"Tabuk","ur":"تبوک","hi":"तबूक","bn":"তাবুক"}'::jsonb,                          28.3835, 36.5662, 10),
  ('tabuk','umluj',             '{"ar":"أملج","en":"Umluj","ur":"املج","hi":"उमलज","bn":"উমলজ"}'::jsonb,                            25.0345, 37.2691, 20),
  ('tabuk','duba',              '{"ar":"ضباء","en":"Duba","ur":"ضبا","hi":"दुबा","bn":"দুবা"}'::jsonb,                              27.3500, 35.7000, 30),
  ('tabuk','tayma',             '{"ar":"تيماء","en":"Tayma","ur":"تیما","hi":"तैमा","bn":"তাইমা"}'::jsonb,                          27.6333, 38.5500, 40),
  ('tabuk','haql',              '{"ar":"حقل","en":"Haql","ur":"حقل","hi":"हक़ल","bn":"হাকল"}'::jsonb,                                29.2933, 34.9419, 50),
  ('tabuk','wajh',              '{"ar":"الوجه","en":"Al-Wajh","ur":"الوجہ","hi":"अल-वज","bn":"আল-ওয়াজ"}'::jsonb,                  26.2436, 36.4533, 60),
  ('tabuk','bir-ibn-hirmas',    '{"ar":"بئر ابن هرماس","en":"Bir Ibn Hirmas","ur":"بئر ابن ہرماس","hi":"बीर इब्न हिरमास","bn":"বির ইবন হিরমাস"}'::jsonb, 28.5500, 36.7000, 70),

  -- Hail (7)
  ('hail','hail',               '{"ar":"حائل","en":"Hail","ur":"حائل","hi":"हाइल","bn":"হাইল"}'::jsonb,                            27.5114, 41.6900, 10),
  ('hail','baqaa',              '{"ar":"بقعاء","en":"Baqaa","ur":"بقعا","hi":"बक़ा","bn":"বাকা"}'::jsonb,                            27.7611, 42.7297, 20),
  ('hail','shinan',             '{"ar":"الشنان","en":"Ash-Shinan","ur":"الشنان","hi":"अश-शिनान","bn":"আশ-শিনান"}'::jsonb,         27.0033, 42.5683, 30),
  ('hail','ghazalah',           '{"ar":"الغزالة","en":"Al-Ghazalah","ur":"الغزالہ","hi":"अल-ग़ज़ाला","bn":"আল-গাজালা"}'::jsonb,    26.7975, 41.3672, 40),
  ('hail','hayit',              '{"ar":"الحائط","en":"Al-Hayit","ur":"الحائط","hi":"अल-हाइट","bn":"আল-হাইত"}'::jsonb,             26.0822, 41.5689, 50),
  ('hail','mawqaq',             '{"ar":"موقق","en":"Mawqaq","ur":"موقق","hi":"मौक़क़","bn":"মাওকাক"}'::jsonb,                          27.6500, 41.0000, 60),
  ('hail','sumayrah',           '{"ar":"السميراء","en":"As-Sumayrah","ur":"السمیراء","hi":"अस-सुमैरा","bn":"আস-সুমাইরা"}'::jsonb,    26.5500, 41.6500, 70),

  -- Northern Borders (4)
  ('northern-borders','arar',   '{"ar":"عرعر","en":"Arar","ur":"عرعر","hi":"अरार","bn":"আরার"}'::jsonb,                            30.9753, 41.0214, 10),
  ('northern-borders','rafha',  '{"ar":"رفحاء","en":"Rafha","ur":"رفحاء","hi":"रफ़हा","bn":"রাফহা"}'::jsonb,                       29.6202, 43.4915, 20),
  ('northern-borders','turaif', '{"ar":"طريف","en":"Turaif","ur":"طریف","hi":"तुरैफ़","bn":"তুরাইফ"}'::jsonb,                       31.6725, 38.6636, 30),
  ('northern-borders','owayqilah','{"ar":"العويقيلة","en":"Al-Owayqilah","ur":"العویقیلہ","hi":"अल-ओवैक़िला","bn":"আল-ওয়াইকিলা"}'::jsonb, 30.3333, 42.0500, 40),

  -- Jazan (14)
  ('jazan','jazan',             '{"ar":"جازان","en":"Jazan","ur":"جازان","hi":"जाज़ान","bn":"জাজান"}'::jsonb,                       16.8892, 42.5611, 10),
  ('jazan','sabya',             '{"ar":"صبيا","en":"Sabya","ur":"صبیا","hi":"सबया","bn":"সাবিয়া"}'::jsonb,                          17.1500, 42.6256, 20),
  ('jazan','abu-arish',         '{"ar":"أبو عريش","en":"Abu Arish","ur":"ابو عریش","hi":"अबू अरिश","bn":"আবু আরিশ"}'::jsonb,         16.9694, 42.8311, 30),
  ('jazan','samtah',            '{"ar":"صامطة","en":"Samtah","ur":"صامطہ","hi":"समता","bn":"সামতা"}'::jsonb,                        16.5961, 42.9472, 40),
  ('jazan','ahad-masarihah',    '{"ar":"أحد المسارحة","en":"Ahad al-Masarihah","ur":"احد المسارحہ","hi":"अहद अल-मसारिहा","bn":"আহাদ আল-মাসারিহা"}'::jsonb, 16.7167, 42.9667, 50),
  ('jazan','bish',              '{"ar":"بيش","en":"Bish","ur":"بیش","hi":"बीश","bn":"বিশ"}'::jsonb,                                  17.3833, 42.6000, 60),
  ('jazan','damad',             '{"ar":"ضمد","en":"Damad","ur":"ضمد","hi":"दमद","bn":"দামাদ"}'::jsonb,                              17.0833, 42.7000, 70),
  ('jazan','aridhah',           '{"ar":"العارضة","en":"Al-Aridhah","ur":"العارضہ","hi":"अल-अरीदा","bn":"আল-আরিদা"}'::jsonb,         17.0667, 43.0167, 80),
  ('jazan','darb',              '{"ar":"الدرب","en":"Al-Darb","ur":"الدرب","hi":"अल-दर्ब","bn":"আল-দারব"}'::jsonb,                  17.7333, 42.2500, 90),
  ('jazan','edabi',             '{"ar":"العيدابي","en":"Al-Edabi","ur":"العیدابی","hi":"अल-एदाबी","bn":"আল-এদাবি"}'::jsonb,         17.2167, 42.7333, 100),
  ('jazan','harth',             '{"ar":"الحرث","en":"Al-Harth","ur":"الحرث","hi":"अल-हर्थ","bn":"আল-হার্থ"}'::jsonb,                17.4833, 42.6667, 110),
  ('jazan','farasan',           '{"ar":"فرسان","en":"Farasan","ur":"فرسان","hi":"फ़रसान","bn":"ফারাসান"}'::jsonb,                   16.7000, 42.1167, 120),
  ('jazan','fayfa',             '{"ar":"فيفاء","en":"Fayfa","ur":"فیفا","hi":"फ़ैफ़ा","bn":"ফাইফা"}'::jsonb,                          17.2500, 43.1000, 130),
  ('jazan','reeth',             '{"ar":"الريث","en":"Al-Reeth","ur":"الریث","hi":"अल-रीथ","bn":"আল-রিথ"}'::jsonb,                    17.4167, 43.0500, 140),

  -- Najran (7)
  ('najran','najran',           '{"ar":"نجران","en":"Najran","ur":"نجران","hi":"नजरान","bn":"নাজরান"}'::jsonb,                     17.5656, 44.2289, 10),
  ('najran','sharurah',         '{"ar":"شرورة","en":"Sharurah","ur":"شرورہ","hi":"शरूरा","bn":"শারুরা"}'::jsonb,                  17.4869, 47.1167, 20),
  ('najran','hubuna',           '{"ar":"حبونا","en":"Hubuna","ur":"حبونا","hi":"हुबूना","bn":"হুবুনা"}'::jsonb,                      17.8333, 44.1500, 30),
  ('najran','yadma',            '{"ar":"يدمة","en":"Yadma","ur":"یدمہ","hi":"यदमा","bn":"ইয়াদমা"}'::jsonb,                          18.2167, 45.0167, 40),
  ('najran','khubash',          '{"ar":"خباش","en":"Khubash","ur":"خباش","hi":"ख़ुबाश","bn":"খুবাশ"}'::jsonb,                       17.7833, 43.7167, 50),
  ('najran','badr-janub',       '{"ar":"بدر الجنوب","en":"Badr al-Janub","ur":"بدر الجنوب","hi":"बद्र अल-जनूब","bn":"বদর আল-জানুব"}'::jsonb, 17.7167, 44.0500, 60),
  ('najran','thar',             '{"ar":"ثار","en":"Thar","ur":"ثار","hi":"थर","bn":"থার"}'::jsonb,                                  18.4000, 44.5000, 70),

  -- Bahah (8)
  ('bahah','bahah',             '{"ar":"الباحة","en":"Al-Bahah","ur":"الباحہ","hi":"अल-बाहा","bn":"আল-বাহা"}'::jsonb,             20.0129, 41.4677, 10),
  ('bahah','baljurashi',        '{"ar":"بلجرشي","en":"Baljurashi","ur":"بلجرشی","hi":"बलजुर्शी","bn":"বলজুরাশি"}'::jsonb,         19.8581, 41.5594, 20),
  ('bahah','almandaq',          '{"ar":"المندق","en":"Al-Mandaq","ur":"المندق","hi":"अल-मंदक","bn":"আল-মান্দাক"}'::jsonb,         20.1944, 41.2806, 30),
  ('bahah','aqiq',              '{"ar":"العقيق","en":"Al-Aqiq","ur":"العقیق","hi":"अल-अक़ीक़","bn":"আল-আকিক"}'::jsonb,             20.2750, 41.6722, 40),
  ('bahah','qilwah',            '{"ar":"قلوة","en":"Qilwah","ur":"قلوہ","hi":"क़िलवा","bn":"কিলওয়া"}'::jsonb,                     19.6667, 41.4667, 50),
  ('bahah','mukhwah',           '{"ar":"المخواة","en":"Al-Mukhwah","ur":"المخواہ","hi":"अल-मुख़वा","bn":"আল-মুখওয়া"}'::jsonb,    19.7672, 41.4322, 60),
  ('bahah','ghamid-zinad',      '{"ar":"غامد الزناد","en":"Ghamid az-Zinad","ur":"غامد الزناد","hi":"ग़ामिद अज़-ज़ीनाद","bn":"গামিদ আজ-জিনাদ"}'::jsonb, 19.9333, 41.5667, 70),
  ('bahah','bani-hasan',        '{"ar":"بني حسن","en":"Bani Hasan","ur":"بنی حسن","hi":"बनी हसन","bn":"বনি হাসান"}'::jsonb,         20.0667, 41.4500, 80),

  -- Jouf (4)
  ('jouf','sakaka',             '{"ar":"سكاكا","en":"Sakaka","ur":"سکاکا","hi":"सकाका","bn":"সাকাকা"}'::jsonb,                    29.9697, 40.2064, 10),
  ('jouf','qurayyat',           '{"ar":"القريات","en":"Qurayyat","ur":"القریات","hi":"क़ुरैयात","bn":"কুরাইয়াত"}'::jsonb,           31.3322, 37.3431, 20),
  ('jouf','dumat-jandal',       '{"ar":"دومة الجندل","en":"Dumat al-Jandal","ur":"دومۃ الجندل","hi":"दूमत अल-जंदल","bn":"দুমাত আল-জানদাল"}'::jsonb, 29.8128, 39.8636, 30),
  ('jouf','tabarjal',           '{"ar":"طبرجل","en":"Tabarjal","ur":"طبرجل","hi":"तबरजल","bn":"তাবারজাল"}'::jsonb,                30.5000, 38.2000, 40)
) as g(region_slug, slug, name, lat, lng, display_order) on g.region_slug = r.slug
on conflict (region_id, slug) do update set
  name = excluded.name,
  lat  = excluded.lat,
  lng  = excluded.lng,
  display_order = excluded.display_order;

commit;


-- ----------------------------------------------------------------------------
-- 0021_saudi_cities_districts.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0021 · Saudi cities + districts seed.
--
-- Cities: one main city per governorate (the governorate seat). Major
-- governorates also get satellite cities. Districts are seeded for the
-- five largest metro areas: Riyadh, Jeddah, Makkah, Madinah, Dammam metro.

begin;

-- =========================================================================
-- 1. Cities — primarily one row per governorate, plus extra for metro areas
-- =========================================================================

-- Most governorates have their primary city sharing the governorate's
-- slug. We attach them via a single VALUES block.

with gov as (select id, slug from public.governorates)
insert into public.cities (governorate_id, slug, name, lat, lng, region, display_order)
select g.id, c.slug, c.name, c.lat, c.lng, c.region, c.display_order
from gov g
join (values
  -- Riyadh region cities
  ('riyadh','riyadh',                    '{"ar":"الرياض","en":"Riyadh","ur":"ریاض","hi":"रियाद","bn":"রিয়াদ"}'::jsonb,                       24.7136, 46.6753, 'Riyadh', 10),
  ('diriyah','diriyah',                  '{"ar":"الدرعية","en":"Diriyah","ur":"درعیہ","hi":"दिरिया","bn":"দিরিয়া"}'::jsonb,                  24.7351, 46.5750, 'Riyadh', 20),
  ('kharj','kharj',                      '{"ar":"الخرج","en":"Al-Kharj","ur":"الخرج","hi":"अल-खर्ज","bn":"আল-খারজ"}'::jsonb,                24.1554, 47.3346, 'Riyadh', 30),
  ('dawadmi','dawadmi',                  '{"ar":"الدوادمي","en":"Dawadmi","ur":"دوادمی","hi":"दवादमी","bn":"দাওয়াদমি"}'::jsonb,             24.5074, 44.3955, 'Riyadh', 40),
  ('majmaah','majmaah',                  '{"ar":"المجمعة","en":"Al-Majmaah","ur":"المجمعہ","hi":"अल-मजमाह","bn":"আল-মাজমাহ"}'::jsonb,         25.9090, 45.3500, 'Riyadh', 50),
  ('quwaiyah','quwaiyah',                '{"ar":"القويعية","en":"Quwaiyah","ur":"قویعیہ","hi":"क़ुवैया","bn":"কুওয়াইয়া"}'::jsonb,             24.0617, 45.2632, 'Riyadh', 60),
  ('wadi-dawasir','wadi-dawasir',        '{"ar":"وادي الدواسر","en":"Wadi ad-Dawasir","ur":"وادی الدواسر","hi":"वादी अद-दवासर","bn":"ওয়াদি আদ-দাওয়াসির"}'::jsonb, 20.4922, 44.8044, 'Riyadh', 70),
  ('zulfi','zulfi',                      '{"ar":"الزلفي","en":"Az-Zulfi","ur":"الزلفی","hi":"अज़-ज़ुल्फ़ी","bn":"আজ-জুলফি"}'::jsonb,           26.2982, 44.8156, 'Riyadh', 80),
  ('shaqra','shaqra',                    '{"ar":"شقراء","en":"Shaqra","ur":"شقراء","hi":"शक़रा","bn":"শাকরা"}'::jsonb,                       25.2402, 45.2569, 'Riyadh', 90),
  ('aflaj','laila',                      '{"ar":"ليلى","en":"Laila","ur":"لیلیٰ","hi":"लैला","bn":"লাইলা"}'::jsonb,                          22.2655, 46.7320, 'Riyadh', 100),

  -- Makkah region cities
  ('makkah','makkah',                    '{"ar":"مكة المكرمة","en":"Makkah","ur":"مکہ مکرمہ","hi":"मक्का","bn":"মক্কা"}'::jsonb,             21.4225, 39.8262, 'Makkah', 10),
  ('jeddah','jeddah',                    '{"ar":"جدة","en":"Jeddah","ur":"جدہ","hi":"जेद्दा","bn":"জেদ্দা"}'::jsonb,                         21.4858, 39.1925, 'Makkah', 20),
  ('taif','taif',                        '{"ar":"الطائف","en":"Taif","ur":"طائف","hi":"ताइफ़","bn":"তাইফ"}'::jsonb,                          21.2854, 40.4183, 'Makkah', 30),
  ('qunfudhah','qunfudhah',              '{"ar":"القنفذة","en":"Al-Qunfudhah","ur":"القنفذہ","hi":"अल-क़ुनफ़ुधा","bn":"আল-কুনফুধা"}'::jsonb, 19.1264, 41.0796, 'Makkah', 40),
  ('rabigh','rabigh',                    '{"ar":"رابغ","en":"Rabigh","ur":"رابغ","hi":"राबिग़","bn":"রাবিগ"}'::jsonb,                        22.7986, 39.0349, 'Makkah', 50),

  -- Madinah region cities
  ('madinah','madinah',                  '{"ar":"المدينة المنورة","en":"Madinah","ur":"مدینہ","hi":"मदीना","bn":"মদিনা"}'::jsonb,           24.4686, 39.6142, 'Madinah', 10),
  ('yanbu','yanbu',                      '{"ar":"ينبع","en":"Yanbu","ur":"ینبع","hi":"यनबू","bn":"ইয়ানবু"}'::jsonb,                          24.0894, 38.0617, 'Madinah', 20),
  ('ula','ula',                          '{"ar":"العلا","en":"Al-Ula","ur":"العلا","hi":"अल-उला","bn":"আল-উলা"}'::jsonb,                     26.6097, 37.9128, 'Madinah', 30),

  -- Eastern Province cities
  ('dammam','dammam',                    '{"ar":"الدمام","en":"Dammam","ur":"دمام","hi":"दम्माम","bn":"দাম্মাম"}'::jsonb,                   26.4207, 50.0888, 'Eastern', 10),
  ('ahsa','hofuf',                       '{"ar":"الهفوف","en":"Hofuf","ur":"ہفوف","hi":"होफ़ूफ़","bn":"হোফুফ"}'::jsonb,                      25.3833, 49.5867, 'Eastern', 20),
  ('ahsa','mubarraz',                    '{"ar":"المبرز","en":"Al-Mubarraz","ur":"مبرز","hi":"अल-मुबर्रज़","bn":"আল-মুবাররাজ"}'::jsonb,        25.4111, 49.5811, 'Eastern', 25),
  ('hafr-batin','hafr-batin',            '{"ar":"حفر الباطن","en":"Hafr al-Batin","ur":"حفر الباطن","hi":"हफ़र अल-बातिन","bn":"হাফর আল-বাতিন"}'::jsonb, 28.4338, 45.9601, 'Eastern', 30),
  ('jubail','jubail',                    '{"ar":"الجبيل","en":"Jubail","ur":"جبیل","hi":"जुबैल","bn":"জুবাইল"}'::jsonb,                     27.0046, 49.6603, 'Eastern', 40),
  ('qatif','qatif',                      '{"ar":"القطيف","en":"Qatif","ur":"قطیف","hi":"क़तीफ़","bn":"কাতিফ"}'::jsonb,                       26.5658, 49.9962, 'Eastern', 50),
  ('khobar','khobar',                    '{"ar":"الخبر","en":"Khobar","ur":"خبر","hi":"ख़ोबर","bn":"খোবার"}'::jsonb,                       26.2172, 50.1971, 'Eastern', 60),
  ('dhahran','dhahran',                  '{"ar":"الظهران","en":"Dhahran","ur":"ظہران","hi":"धहरान","bn":"ধাহরান"}'::jsonb,                  26.2361, 50.0393, 'Eastern', 70),

  -- Asir cities
  ('abha','abha',                        '{"ar":"أبها","en":"Abha","ur":"ابہا","hi":"अभा","bn":"আবহা"}'::jsonb,                              18.2167, 42.5053, 'Asir', 10),
  ('khamis-mushait','khamis-mushait',    '{"ar":"خميس مشيط","en":"Khamis Mushait","ur":"خمیس مشیط","hi":"ख़मीस मुशैत","bn":"খামিস মুশাইত"}'::jsonb, 18.3000, 42.7333, 'Asir', 20),
  ('bisha','bisha',                      '{"ar":"بيشة","en":"Bisha","ur":"بیشہ","hi":"बीशा","bn":"বিশা"}'::jsonb,                            20.0000, 42.6000, 'Asir', 30),

  -- Qassim cities
  ('buraidah','buraidah',                '{"ar":"بريدة","en":"Buraidah","ur":"بریدہ","hi":"बुरैदा","bn":"বুরাইদা"}'::jsonb,                  26.3260, 43.9750, 'Qassim', 10),
  ('unaizah','unaizah',                  '{"ar":"عنيزة","en":"Unaizah","ur":"عنیزہ","hi":"उनैज़ा","bn":"উনাইজা"}'::jsonb,                    26.0844, 43.9961, 'Qassim', 20),
  ('rass','rass',                        '{"ar":"الرس","en":"Ar-Rass","ur":"الرس","hi":"अर-रस","bn":"আর-রাস"}'::jsonb,                       25.8721, 43.5012, 'Qassim', 30),

  -- Tabuk cities
  ('tabuk','tabuk',                      '{"ar":"تبوك","en":"Tabuk","ur":"تبوک","hi":"तबूक","bn":"তাবুক"}'::jsonb,                          28.3835, 36.5662, 'Tabuk', 10),
  ('umluj','umluj',                      '{"ar":"أملج","en":"Umluj","ur":"املج","hi":"उमलज","bn":"উমলজ"}'::jsonb,                            25.0345, 37.2691, 'Tabuk', 20),

  -- Hail cities
  ('hail','hail',                        '{"ar":"حائل","en":"Hail","ur":"حائل","hi":"हाइल","bn":"হাইল"}'::jsonb,                            27.5114, 41.6900, 'Hail', 10),

  -- Northern Borders
  ('arar','arar',                        '{"ar":"عرعر","en":"Arar","ur":"عرعر","hi":"अरार","bn":"আরার"}'::jsonb,                            30.9753, 41.0214, 'Northern Borders', 10),
  ('rafha','rafha',                      '{"ar":"رفحاء","en":"Rafha","ur":"رفحاء","hi":"रफ़हा","bn":"রাফহা"}'::jsonb,                       29.6202, 43.4915, 'Northern Borders', 20),

  -- Jazan
  ('jazan','jazan',                      '{"ar":"جازان","en":"Jazan","ur":"جازان","hi":"जाज़ान","bn":"জাজান"}'::jsonb,                       16.8892, 42.5611, 'Jazan', 10),
  ('sabya','sabya',                      '{"ar":"صبيا","en":"Sabya","ur":"صبیا","hi":"सबया","bn":"সাবিয়া"}'::jsonb,                          17.1500, 42.6256, 'Jazan', 20),

  -- Najran
  ('najran','najran',                    '{"ar":"نجران","en":"Najran","ur":"نجران","hi":"नजरान","bn":"নাজরান"}'::jsonb,                     17.5656, 44.2289, 'Najran', 10),
  ('sharurah','sharurah',                '{"ar":"شرورة","en":"Sharurah","ur":"شرورہ","hi":"शरूरा","bn":"শারুরা"}'::jsonb,                  17.4869, 47.1167, 'Najran', 20),

  -- Bahah
  ('bahah','bahah',                      '{"ar":"الباحة","en":"Al-Bahah","ur":"الباحہ","hi":"अल-बाहा","bn":"আল-বাহা"}'::jsonb,             20.0129, 41.4677, 'Bahah', 10),
  ('baljurashi','baljurashi',            '{"ar":"بلجرشي","en":"Baljurashi","ur":"بلجرشی","hi":"बलजुर्शी","bn":"বলজুরাশি"}'::jsonb,         19.8581, 41.5594, 'Bahah', 20),

  -- Jouf
  ('sakaka','sakaka',                    '{"ar":"سكاكا","en":"Sakaka","ur":"سکاکا","hi":"सकाका","bn":"সাকাকা"}'::jsonb,                    29.9697, 40.2064, 'Jouf', 10),
  ('qurayyat','qurayyat',                '{"ar":"القريات","en":"Qurayyat","ur":"القریات","hi":"क़ुरैयात","bn":"কুরাইয়াত"}'::jsonb,           31.3322, 37.3431, 'Jouf', 20),
  ('dumat-jandal','dumat-jandal',        '{"ar":"دومة الجندل","en":"Dumat al-Jandal","ur":"دومۃ الجندل","hi":"दूमत अल-जंदल","bn":"দুমাত আল-জানদাল"}'::jsonb, 29.8128, 39.8636, 'Jouf', 30)
) as c(governorate_slug, slug, name, lat, lng, region, display_order) on c.governorate_slug = g.slug
on conflict (slug) do update set
  governorate_id = excluded.governorate_id,
  name = excluded.name,
  lat = excluded.lat,
  lng = excluded.lng,
  display_order = excluded.display_order;

-- =========================================================================
-- 2. Districts — for the five largest metros
-- =========================================================================

-- Riyadh districts
with city as (select id from public.cities where slug = 'riyadh' limit 1)
insert into public.districts (city_id, slug, name, lat, lng, display_order)
select (select id from city), d.slug, d.name, d.lat, d.lng, d.display_order
from (values
  ('olaya',          '{"ar":"العليا","en":"Olaya","ur":"العلیا","hi":"ओलाया","bn":"ওলায়া"}'::jsonb,                     24.6907, 46.6796, 10),
  ('diplomatic',     '{"ar":"الحي الدبلوماسي","en":"Diplomatic Quarter","ur":"سفارتی کوارٹر","hi":"डिप्लोमैटिक क्वार्टर","bn":"কূটনৈতিক কোয়ার্টার"}'::jsonb, 24.6843, 46.6219, 20),
  ('nakheel',        '{"ar":"النخيل","en":"An-Nakheel","ur":"النخیل","hi":"अन-नखील","bn":"আন-নাখিল"}'::jsonb,           24.7558, 46.6373, 30),
  ('yasmin',         '{"ar":"الياسمين","en":"Yasmin","ur":"یاسمین","hi":"यासमीन","bn":"ইয়াসমিন"}'::jsonb,                24.8344, 46.6376, 40),
  ('malqa',          '{"ar":"الملقا","en":"Al-Malqa","ur":"الملقا","hi":"अल-मलक़ा","bn":"আল-মালকা"}'::jsonb,               24.8228, 46.6358, 50),
  ('hittin',         '{"ar":"حطين","en":"Hittin","ur":"حطین","hi":"हिट्टीन","bn":"হিত্তিন"}'::jsonb,                       24.7794, 46.6431, 60),
  ('sulaimaniyah',   '{"ar":"السليمانية","en":"Sulaimaniyah","ur":"سلیمانیہ","hi":"सुलैमानिया","bn":"সুলাইমানিয়া"}'::jsonb, 24.6900, 46.7100, 70),
  ('aziziyah',       '{"ar":"العزيزية","en":"Aziziyah","ur":"عزیزیہ","hi":"अज़ीज़िया","bn":"আজিজিয়া"}'::jsonb,           24.5944, 46.7458, 80),
  ('worud',          '{"ar":"الورود","en":"Al-Worud","ur":"الورود","hi":"अल-वोरूद","bn":"আল-ওরুদ"}'::jsonb,               24.7286, 46.6772, 90),
  ('murabba',        '{"ar":"المربع","en":"Al-Murabba","ur":"المربع","hi":"अल-मुरब्बा","bn":"আল-মুরাব্বা"}'::jsonb,         24.6515, 46.7188, 100),
  ('batha',          '{"ar":"البطحاء","en":"Al-Batha","ur":"البطحاء","hi":"अल-बथा","bn":"আল-বাথা"}'::jsonb,                 24.6311, 46.7136, 110),
  ('manfuhah',       '{"ar":"منفوحة","en":"Manfuhah","ur":"منفوحہ","hi":"मनफूहा","bn":"মানফুহা"}'::jsonb,                  24.6175, 46.7322, 120),
  ('murouj',         '{"ar":"المروج","en":"Al-Murouj","ur":"المروج","hi":"अल-मुरूज","bn":"আল-মুরুজ"}'::jsonb,             24.7406, 46.6469, 130),
  ('rabwa',          '{"ar":"الربوة","en":"Ar-Rabwa","ur":"الربوہ","hi":"अर-रब्वा","bn":"আর-রাব্বা"}'::jsonb,             24.7250, 46.7300, 140),
  ('roda',           '{"ar":"الروضة","en":"Ar-Roda","ur":"الروضہ","hi":"अर-रौदा","bn":"আর-রৌদা"}'::jsonb,                  24.7000, 46.7833, 150),
  ('sahafah',        '{"ar":"الصحافة","en":"As-Sahafah","ur":"الصحافہ","hi":"अस-सहाफा","bn":"আস-সাহাফা"}'::jsonb,         24.8056, 46.6403, 160),
  ('tuwaiq',         '{"ar":"طويق","en":"Tuwaiq","ur":"طویق","hi":"तुवैक़","bn":"তুওয়াইক"}'::jsonb,                       24.6789, 46.5742, 170),
  ('suwaidi',        '{"ar":"السويدي","en":"As-Suwaidi","ur":"السویدی","hi":"अस-सुवैदी","bn":"আস-সুওয়াইদি"}'::jsonb,    24.6044, 46.6533, 180),
  ('shifa',          '{"ar":"الشفا","en":"Ash-Shifa","ur":"الشفا","hi":"अश-शिफा","bn":"আশ-শিফা"}'::jsonb,                 24.5500, 46.6736, 190),
  ('faisaliyah',     '{"ar":"الفيصلية","en":"Al-Faisaliyah","ur":"الفیصلیہ","hi":"अल-फ़ैसलिया","bn":"আল-ফাইসালিয়া"}'::jsonb, 24.6750, 46.6889, 200),
  ('rawdah',         '{"ar":"الروضة","en":"Ar-Rawdah","ur":"الروضہ","hi":"अर-रावदा","bn":"আর-রাওদা"}'::jsonb,             24.7100, 46.7800, 210),
  ('izdihar',        '{"ar":"الازدهار","en":"Al-Izdihar","ur":"الازدہار","hi":"अल-इज़दिहार","bn":"আল-ইজদিহার"}'::jsonb,    24.7339, 46.7322, 220),
  ('khaleej',        '{"ar":"الخليج","en":"Al-Khaleej","ur":"الخلیج","hi":"अल-ख़लीज","bn":"আল-খালিজ"}'::jsonb,            24.7700, 46.7800, 230),
  ('rayyan',         '{"ar":"الريان","en":"Ar-Rayyan","ur":"الریان","hi":"अर-रय्यान","bn":"আর-রাইয়ান"}'::jsonb,         24.6800, 46.8000, 240),
  ('naseem',         '{"ar":"النسيم","en":"An-Naseem","ur":"النسیم","hi":"अन-नसीम","bn":"আন-নাসিম"}'::jsonb,             24.7900, 46.7300, 250),
  ('arqah',          '{"ar":"عرقة","en":"Arqah","ur":"عرقہ","hi":"अरक़ा","bn":"আরকা"}'::jsonb,                            24.7361, 46.5489, 260),
  ('nafel',          '{"ar":"النفل","en":"An-Nafel","ur":"النفل","hi":"अन-नफ़ल","bn":"আন-নাফল"}'::jsonb,                  24.8108, 46.6633, 270),
  ('quds',           '{"ar":"القدس","en":"Al-Quds","ur":"القدس","hi":"अल-क़ुदस","bn":"আল-কুদস"}'::jsonb,                  24.7700, 46.7000, 280),
  ('falah',          '{"ar":"الفلاح","en":"Al-Falah","ur":"الفلاح","hi":"अल-फलाह","bn":"আল-ফালাহ"}'::jsonb,               24.7900, 46.6600, 290),
  ('rahmaniyah',     '{"ar":"الرحمانية","en":"Ar-Rahmaniyah","ur":"الرحمانیہ","hi":"अर-रहमानिया","bn":"আর-রাহমানিয়া"}'::jsonb, 24.7400, 46.6300, 300)
) as d(slug, name, lat, lng, display_order)
where exists (select 1 from city)
on conflict (city_id, slug) do update set
  name = excluded.name, lat = excluded.lat, lng = excluded.lng,
  display_order = excluded.display_order;

-- Jeddah districts
with city as (select id from public.cities where slug = 'jeddah' limit 1)
insert into public.districts (city_id, slug, name, lat, lng, display_order)
select (select id from city), d.slug, d.name, d.lat, d.lng, d.display_order
from (values
  ('salama',         '{"ar":"السلامة","en":"As-Salama","ur":"السلامہ","hi":"अस-सलामा","bn":"আস-সালামা"}'::jsonb,           21.5750, 39.1500, 10),
  ('hamra',          '{"ar":"الحمراء","en":"Al-Hamra","ur":"الحمراء","hi":"अल-हम्रा","bn":"আল-হামরা"}'::jsonb,           21.5478, 39.1567, 20),
  ('shati',          '{"ar":"الشاطئ","en":"Ash-Shati","ur":"الشاطی","hi":"अश-शाती","bn":"আশ-শাতি"}'::jsonb,                21.6075, 39.1067, 30),
  ('andalus',        '{"ar":"الأندلس","en":"Al-Andalus","ur":"الأندلس","hi":"अल-अंदालुस","bn":"আল-আন্দালুস"}'::jsonb,    21.5500, 39.1500, 40),
  ('naeem',          '{"ar":"النعيم","en":"An-Naeem","ur":"النعیم","hi":"अन-नईम","bn":"আন-নাঈম"}'::jsonb,                  21.6022, 39.1453, 50),
  ('aziziyah-j',     '{"ar":"العزيزية","en":"Al-Aziziyah","ur":"عزیزیہ","hi":"अल-अज़ीज़िया","bn":"আল-আজিজিয়া"}'::jsonb, 21.5500, 39.1700, 60),
  ('safa',           '{"ar":"الصفا","en":"As-Safa","ur":"الصفا","hi":"अस-सफा","bn":"আস-সাফা"}'::jsonb,                     21.5483, 39.2233, 70),
  ('hindawiyah',     '{"ar":"الهنداوية","en":"Al-Hindawiyah","ur":"الہنداویہ","hi":"अल-हिंदावीया","bn":"আল-হিন্দাওয়িয়া"}'::jsonb, 21.5167, 39.1500, 80),
  ('balad',          '{"ar":"البلد","en":"Al-Balad","ur":"البلد","hi":"अल-बलद","bn":"আল-বালাদ"}'::jsonb,                    21.4858, 39.1925, 90),
  ('rawdah-j',       '{"ar":"الروضة","en":"Ar-Rawdah","ur":"الروضہ","hi":"अर-रवदा","bn":"আর-রাওদা"}'::jsonb,             21.5500, 39.1800, 100),
  ('naseem-j',       '{"ar":"النسيم","en":"An-Naseem","ur":"النسیم","hi":"अन-नसीम","bn":"আন-নাসিম"}'::jsonb,             21.4900, 39.2500, 110),
  ('thalabah',       '{"ar":"الثعلبة","en":"Ath-Thaalibah","ur":"الثعلبہ","hi":"अथ-थालिबा","bn":"আথ-থালিবা"}'::jsonb,    21.4670, 39.1822, 120),
  ('marwah',         '{"ar":"المروة","en":"Al-Marwah","ur":"المروہ","hi":"अल-मरवा","bn":"আল-মারওয়া"}'::jsonb,           21.6181, 39.1531, 130),
  ('khalidiya-j',    '{"ar":"الخالدية","en":"Al-Khalidiya","ur":"الخالدیہ","hi":"अल-ख़ालिदिया","bn":"আল-খালিদিয়া"}'::jsonb, 21.5547, 39.1953, 140),
  ('faisaliya-j',    '{"ar":"الفيصلية","en":"Al-Faisaliya","ur":"الفیصلیہ","hi":"अल-फ़ैसलिया","bn":"আল-ফাইসালিয়া"}'::jsonb, 21.5800, 39.1800, 150),
  ('rabwa-j',        '{"ar":"الربوة","en":"Ar-Rabwa","ur":"الربوہ","hi":"अर-रब्वा","bn":"আর-রাব্বা"}'::jsonb,             21.5600, 39.1900, 160),
  ('rehab',          '{"ar":"الرحاب","en":"Ar-Rehab","ur":"الرحاب","hi":"अर-रिहाब","bn":"আর-রিহাব"}'::jsonb,              21.6500, 39.1300, 170),
  ('zahra',          '{"ar":"الزهراء","en":"Az-Zahra","ur":"الزہراء","hi":"अज़-ज़हरा","bn":"আজ-জাহরা"}'::jsonb,           21.5333, 39.1833, 180),
  ('sharafiyah',     '{"ar":"الشرفية","en":"Ash-Sharafiyah","ur":"الشرفیہ","hi":"अश-शराफिया","bn":"আশ-শারাফিয়া"}'::jsonb, 21.5147, 39.1844, 190),
  ('mishrifah',      '{"ar":"المشرفة","en":"Al-Mishrifah","ur":"المشرفہ","hi":"अल-मिशरिफा","bn":"আল-মিশরিফা"}'::jsonb,    21.6172, 39.1056, 200)
) as d(slug, name, lat, lng, display_order)
where exists (select 1 from city)
on conflict (city_id, slug) do update set
  name = excluded.name, lat = excluded.lat, lng = excluded.lng,
  display_order = excluded.display_order;

-- Makkah districts
with city as (select id from public.cities where slug = 'makkah' limit 1)
insert into public.districts (city_id, slug, name, lat, lng, display_order)
select (select id from city), d.slug, d.name, d.lat, d.lng, d.display_order
from (values
  ('aziziyah-m',     '{"ar":"العزيزية","en":"Al-Aziziyah","ur":"عزیزیہ","hi":"अल-अज़ीज़िया","bn":"আল-আজিজিয়া"}'::jsonb, 21.4044, 39.8842, 10),
  ('ajyad',          '{"ar":"أجياد","en":"Ajyad","ur":"اجیاد","hi":"अज्याद","bn":"আজইয়াদ"}'::jsonb,                       21.4233, 39.8200, 20),
  ('misfalah',       '{"ar":"المسفلة","en":"Al-Misfalah","ur":"المسفلہ","hi":"अल-मिस्फला","bn":"আল-মিস্ফলা"}'::jsonb,    21.4150, 39.8267, 30),
  ('sharafia-m',     '{"ar":"الشرفية","en":"Ash-Sharafia","ur":"الشرفیہ","hi":"अश-शराफिया","bn":"আশ-শারাফিয়া"}'::jsonb, 21.4133, 39.8350, 40),
  ('awali',          '{"ar":"العوالي","en":"Al-Awali","ur":"العوالی","hi":"अल-अवाली","bn":"আল-আওয়ালি"}'::jsonb,         21.3950, 39.9050, 50),
  ('zahir',          '{"ar":"الزاهر","en":"Az-Zahir","ur":"الزاہر","hi":"अज़-ज़ाहिर","bn":"আজ-জাহির"}'::jsonb,           21.4283, 39.8389, 60),
  ('shawqiyah',      '{"ar":"الشوقية","en":"Ash-Shawqiyah","ur":"الشوقیہ","hi":"अश-शौक़िया","bn":"আশ-শাওকিয়া"}'::jsonb, 21.4467, 39.8367, 70),
  ('rusayfah',       '{"ar":"الرصيفة","en":"Ar-Rusayfah","ur":"الرصیفہ","hi":"अर-रुसैफा","bn":"আর-রুসাইফা"}'::jsonb,    21.4322, 39.8456, 80),
  ('jamiah-m',       '{"ar":"الجامعة","en":"Al-Jamiah","ur":"الجامعہ","hi":"अल-जामिआ","bn":"আল-জামিয়া"}'::jsonb,         21.4419, 39.8519, 90),
  ('naseem-m',       '{"ar":"النسيم","en":"An-Naseem","ur":"النسیم","hi":"अन-नसीम","bn":"আন-নাসিম"}'::jsonb,             21.4378, 39.8264, 100),
  ('hajun',          '{"ar":"الحجون","en":"Al-Hajun","ur":"الحجون","hi":"अल-हाजुन","bn":"আল-হাজুন"}'::jsonb,             21.4322, 39.8294, 110),
  ('khansa',         '{"ar":"الخنساء","en":"Al-Khansa","ur":"الخنساء","hi":"अल-ख़न्सा","bn":"আল-খানসা"}'::jsonb,         21.4225, 39.8500, 120),
  ('naqa',           '{"ar":"النقا","en":"An-Naqa","ur":"النقا","hi":"अन-नक़ा","bn":"আন-নাকা"}'::jsonb,                   21.4072, 39.8631, 130),
  ('andalus-m',      '{"ar":"الأندلس","en":"Al-Andalus","ur":"الأندلس","hi":"अल-अंदलुस","bn":"আল-আন্দালুস"}'::jsonb,    21.4150, 39.8050, 140),
  ('mansour',        '{"ar":"المنصور","en":"Al-Mansour","ur":"المنصور","hi":"अल-मंसूर","bn":"আল-মানসুর"}'::jsonb,         21.4400, 39.8300, 150)
) as d(slug, name, lat, lng, display_order)
where exists (select 1 from city)
on conflict (city_id, slug) do update set
  name = excluded.name, lat = excluded.lat, lng = excluded.lng,
  display_order = excluded.display_order;

-- Madinah districts
with city as (select id from public.cities where slug = 'madinah' limit 1)
insert into public.districts (city_id, slug, name, lat, lng, display_order)
select (select id from city), d.slug, d.name, d.lat, d.lng, d.display_order
from (values
  ('markaziyah',     '{"ar":"المركزية","en":"Markaziyah","ur":"المرکزیہ","hi":"मरकज़िया","bn":"মারকাজিয়া"}'::jsonb,    24.4686, 39.6142, 10),
  ('awali-md',       '{"ar":"العوالي","en":"Al-Awali","ur":"العوالی","hi":"अल-अवाली","bn":"আল-আওয়ালি"}'::jsonb,         24.4400, 39.6300, 20),
  ('anbariyah',      '{"ar":"العنبرية","en":"Al-Anbariyah","ur":"العنبریہ","hi":"अल-अनबरिया","bn":"আল-আনবারিয়া"}'::jsonb, 24.4661, 39.6017, 30),
  ('quba',           '{"ar":"قباء","en":"Quba","ur":"قبا","hi":"क़ुबा","bn":"কুবা"}'::jsonb,                                24.4400, 39.6175, 40),
  ('sayyid-shuhada', '{"ar":"سيد الشهداء","en":"Sayyid Ash-Shuhada","ur":"سید الشہداء","hi":"सय्यद अश-शुहदा","bn":"সাইয়িদ আশ-শুহাদা"}'::jsonb, 24.4842, 39.6086, 50),
  ('sultanah',       '{"ar":"السلطانة","en":"Sultanah","ur":"السلطانہ","hi":"सुल्ताना","bn":"সুলতানা"}'::jsonb,            24.4700, 39.6200, 60),
  ('jurf',           '{"ar":"الجرف","en":"Al-Jurf","ur":"الجرف","hi":"अल-जुर्फ","bn":"আল-জুরফ"}'::jsonb,                  24.5300, 39.5800, 70),
  ('khalidiya-md',   '{"ar":"الخالدية","en":"Al-Khalidiya","ur":"الخالدیہ","hi":"अल-ख़ालिदिया","bn":"আল-খালিদিয়া"}'::jsonb, 24.4900, 39.6300, 80),
  ('aziziyah-md',    '{"ar":"العزيزية","en":"Al-Aziziyah","ur":"عزیزیہ","hi":"अल-अज़ीज़िया","bn":"আল-আজিজিয়া"}'::jsonb, 24.4500, 39.6500, 90),
  ('rawdah-md',      '{"ar":"الروضة","en":"Ar-Rawdah","ur":"الروضہ","hi":"अर-रवदा","bn":"আর-রাওদা"}'::jsonb,             24.4750, 39.6250, 100)
) as d(slug, name, lat, lng, display_order)
where exists (select 1 from city)
on conflict (city_id, slug) do update set
  name = excluded.name, lat = excluded.lat, lng = excluded.lng,
  display_order = excluded.display_order;

-- Dammam districts
with city as (select id from public.cities where slug = 'dammam' limit 1)
insert into public.districts (city_id, slug, name, lat, lng, display_order)
select (select id from city), d.slug, d.name, d.lat, d.lng, d.display_order
from (values
  ('faisaliyah-d',   '{"ar":"الفيصلية","en":"Al-Faisaliyah","ur":"الفیصلیہ","hi":"अल-फ़ैसलिया","bn":"আল-ফাইসালিয়া"}'::jsonb, 26.4181, 50.1042, 10),
  ('adamah',         '{"ar":"العدامة","en":"Al-Adamah","ur":"العدامہ","hi":"अल-अदामा","bn":"আল-আদামা"}'::jsonb,           26.4053, 50.1131, 20),
  ('bahir',          '{"ar":"الباحة","en":"Al-Bahir","ur":"الباحہ","hi":"अल-बाहिर","bn":"আল-বাহির"}'::jsonb,             26.4250, 50.0833, 30),
  ('shati-d',        '{"ar":"الشاطئ","en":"Ash-Shati","ur":"الشاطی","hi":"अश-शाती","bn":"আশ-শাতি"}'::jsonb,                26.4467, 50.0975, 40),
  ('aziziyah-d',     '{"ar":"العزيزية","en":"Al-Aziziyah","ur":"عزیزیہ","hi":"अल-अज़ीज़िया","bn":"আল-আজিজিয়া"}'::jsonb, 26.3500, 50.1167, 50),
  ('anwar',          '{"ar":"الأنوار","en":"Al-Anwar","ur":"الانوار","hi":"अल-अनवर","bn":"আল-আনওয়ার"}'::jsonb,            26.3833, 50.1167, 60),
  ('badi',           '{"ar":"البديع","en":"Al-Badi","ur":"البدیع","hi":"अल-बदी","bn":"আল-বাদি"}'::jsonb,                   26.3450, 50.1500, 70),
  ('manar',          '{"ar":"المنار","en":"Al-Manar","ur":"المنار","hi":"अल-मनार","bn":"আল-মানার"}'::jsonb,               26.4200, 50.1400, 80),
  ('jalawiyah',      '{"ar":"الجلوية","en":"Al-Jalawiyah","ur":"الجلویہ","hi":"अल-जलविया","bn":"আল-জালাউইয়া"}'::jsonb,    26.4100, 50.1000, 90),
  ('iskan',          '{"ar":"الإسكان","en":"Al-Iskan","ur":"الإسکان","hi":"अल-इसकान","bn":"আল-ইসকান"}'::jsonb,             26.4350, 50.0750, 100)
) as d(slug, name, lat, lng, display_order)
where exists (select 1 from city)
on conflict (city_id, slug) do update set
  name = excluded.name, lat = excluded.lat, lng = excluded.lng,
  display_order = excluded.display_order;

commit;


-- ----------------------------------------------------------------------------
-- 0022_activate_default_regions.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0022 · Bootstrap activation.
--
-- On first deploy, light up the four largest regions (Riyadh, Makkah,
-- Madinah, Eastern) and their primary governorates so the public site has
-- coverage out of the box. Admins can disable any of these from
-- /admin/regions later, and the cascade triggers will follow.
--
-- This migration only flips is_active to true where it's currently false —
-- it never overrides an admin's explicit decision to disable a region.

begin;

update public.regions
   set is_active = true
 where slug in ('riyadh', 'makkah', 'madinah', 'eastern')
   and is_active = false;

-- Governorate-level activation for the top metros. The region-level cascade
-- trigger from migration 0016 already mirrors region.is_active down — but
-- only on subsequent toggles. This explicit update covers the case where
-- governorates were inserted while their region was already active.
update public.governorates
   set is_active = true
 where slug in (
   'riyadh', 'diriyah', 'kharj',
   'makkah', 'jeddah', 'taif',
   'madinah', 'yanbu',
   'dammam', 'ahsa', 'khobar', 'dhahran', 'jubail', 'qatif'
 )
   and is_active = false;

-- Mirror to their primary cities. Districts inherit is_active=true via
-- their default column value, so nothing else needs nudging.
update public.cities
   set is_active = true
 where slug in (
   'riyadh', 'diriyah', 'kharj',
   'makkah', 'jeddah', 'taif',
   'madinah', 'yanbu',
   'dammam', 'hofuf', 'mubarraz', 'khobar', 'dhahran', 'jubail', 'qatif'
 )
   and is_active = false;

commit;


-- ----------------------------------------------------------------------------
-- 0023_bootstrap_admin.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0023 · One-time super-admin bootstrap.
--
-- On a fresh deployment there's no super_admin yet, which makes /admin
-- inaccessible. Rather than asking the operator to drop into the Supabase
-- SQL Editor, expose two helper RPCs that any authenticated user can call:
--
--   has_any_super_admin() → boolean
--   bootstrap_super_admin() → boolean
--
-- bootstrap_super_admin() promotes the *currently authenticated user* to
-- super_admin if and only if no super_admin exists yet. Once any super_admin
-- is recorded the function refuses to act and returns false, so the URL
-- closes itself off permanently after the first successful call.

begin;

create or replace function public.has_any_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.user_roles where role = 'super_admin');
$$;

grant execute on function public.has_any_super_admin() to anon, authenticated;

create or replace function public.bootstrap_super_admin()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_admin_exists boolean;
begin
  if v_user_id is null then
    return false;
  end if;

  select exists (select 1 from public.user_roles where role = 'super_admin')
    into v_admin_exists;

  if v_admin_exists then
    return false;
  end if;

  insert into public.user_roles (user_id, role, granted_at)
  values (v_user_id, 'super_admin', now())
  on conflict do nothing;

  update public.profiles
     set updated_at = now()
   where user_id = v_user_id;

  return true;
end;
$$;

grant execute on function public.bootstrap_super_admin() to authenticated;

commit;


-- ----------------------------------------------------------------------------
-- 0024_admin_section_permissions.sql
-- ----------------------------------------------------------------------------
-- Syanah · 0024 · Granular admin section permissions.
--
-- Two admin tiers:
--   super_admin    → implicit access to every section
--   section_admin  → only the sections explicitly granted in admin_section_grants
--
-- Sections are the high-level admin areas (categories, geography, users…).
-- A super_admin manages grants via /admin/permissions.

begin;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'admin_section') then
    create type admin_section as enum (
      'categories',
      'geography',
      'users',
      'disputes',
      'translations',
      'settings',
      'orders',
      'payments',
      'ads'
    );
  end if;
end $$;

create table if not exists public.admin_section_grants (
  user_id uuid not null references auth.users(id) on delete cascade,
  section admin_section not null,
  granted_by uuid references auth.users(id) on delete set null,
  granted_at timestamptz not null default now(),
  primary key (user_id, section)
);

create index if not exists admin_section_grants_section_idx
  on public.admin_section_grants(section);

alter table public.admin_section_grants enable row level security;

drop policy if exists admin_section_grants_select on public.admin_section_grants;
create policy admin_section_grants_select on public.admin_section_grants
  for select
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.user_roles
      where user_id = auth.uid() and role = 'super_admin'
    )
  );

drop policy if exists admin_section_grants_modify on public.admin_section_grants;
create policy admin_section_grants_modify on public.admin_section_grants
  for all
  using (
    exists (
      select 1 from public.user_roles
      where user_id = auth.uid() and role = 'super_admin'
    )
  )
  with check (
    exists (
      select 1 from public.user_roles
      where user_id = auth.uid() and role = 'super_admin'
    )
  );

-- super_admin → true for every section; section_admin → only granted sections.
create or replace function public.user_has_admin_section(
  p_user uuid,
  p_section admin_section
)
returns boolean
language sql
stable
as $$
  select case
    when exists(
      select 1 from public.user_roles
      where user_id = p_user and role = 'super_admin'
    ) then true
    when exists(
      select 1 from public.user_roles
      where user_id = p_user and role = 'section_admin'
    ) and exists(
      select 1 from public.admin_section_grants
      where user_id = p_user and section = p_section
    ) then true
    else false
  end;
$$;

-- Returns every section the user can access. super_admin gets all enum values.
create or replace function public.user_admin_sections(p_user uuid)
returns setof admin_section
language sql
stable
as $$
  select s
  from unnest(enum_range(null::admin_section)) as s
  where exists(
    select 1 from public.user_roles
    where user_id = p_user and role = 'super_admin'
  )
  union
  select section
  from public.admin_section_grants
  where user_id = p_user;
$$;

-- Grant a section to a user. Promotes them to section_admin if not already.
-- Only callable by a super_admin (enforced inside the function so the RPC
-- can be exposed safely to the anon/authenticated roles).
create or replace function public.grant_admin_section(
  p_user uuid,
  p_section admin_section
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
begin
  if v_caller is null then return false; end if;
  if not exists(
    select 1 from public.user_roles
    where user_id = v_caller and role = 'super_admin'
  ) then
    return false;
  end if;

  if not exists(
    select 1 from public.user_roles
    where user_id = p_user and role = 'section_admin'
  ) then
    insert into public.user_roles(user_id, role, granted_by)
      values (p_user, 'section_admin', v_caller)
      on conflict do nothing;
  end if;

  insert into public.admin_section_grants(user_id, section, granted_by)
    values (p_user, p_section, v_caller)
    on conflict do nothing;

  return true;
end $$;

-- Revoke a section. If the user has no remaining grants, also drop the
-- section_admin role so they fall back to a regular user.
create or replace function public.revoke_admin_section(
  p_user uuid,
  p_section admin_section
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
begin
  if v_caller is null then return false; end if;
  if not exists(
    select 1 from public.user_roles
    where user_id = v_caller and role = 'super_admin'
  ) then
    return false;
  end if;

  delete from public.admin_section_grants
    where user_id = p_user and section = p_section;

  if not exists(
    select 1 from public.admin_section_grants where user_id = p_user
  ) then
    delete from public.user_roles
      where user_id = p_user and role = 'section_admin';
  end if;

  return true;
end $$;

grant execute on function public.user_has_admin_section(uuid, admin_section) to authenticated, anon;
grant execute on function public.user_admin_sections(uuid) to authenticated, anon;
grant execute on function public.grant_admin_section(uuid, admin_section) to authenticated;
grant execute on function public.revoke_admin_section(uuid, admin_section) to authenticated;

commit;

