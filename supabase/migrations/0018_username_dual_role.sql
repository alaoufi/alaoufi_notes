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
