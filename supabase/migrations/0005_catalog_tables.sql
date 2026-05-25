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
