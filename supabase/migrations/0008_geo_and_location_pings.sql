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
