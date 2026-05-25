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
