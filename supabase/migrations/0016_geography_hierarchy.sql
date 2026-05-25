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
