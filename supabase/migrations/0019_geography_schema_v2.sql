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
