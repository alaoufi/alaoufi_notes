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
