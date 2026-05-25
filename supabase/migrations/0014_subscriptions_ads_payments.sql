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
