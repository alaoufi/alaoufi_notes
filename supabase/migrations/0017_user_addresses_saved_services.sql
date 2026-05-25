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
