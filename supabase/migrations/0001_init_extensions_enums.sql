-- Syanah · 0001 · Extensions and enum types.
-- These are foundation pieces required by every later migration.

begin;

create extension if not exists "pgcrypto";
create extension if not exists "pg_trgm";

-- enums

do $$ begin
  if not exists (select 1 from pg_type where typname = 'user_role') then
    create type user_role as enum ('super_admin', 'section_admin', 'provider', 'requester');
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'verification_method') then
    create type verification_method as enum ('nafath', 'sms', 'whatsapp', 'email');
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'verification_status') then
    create type verification_status as enum ('pending', 'verified', 'expired', 'failed');
  end if;
end $$;

-- shared trigger function to maintain updated_at on row updates.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

commit;
