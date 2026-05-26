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
