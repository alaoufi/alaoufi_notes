-- ============================================================================
-- Syanah · DESTRUCTIVE RESET
-- ============================================================================
-- Wipes every Syanah table, view, function, trigger, and enum, then resets the
-- public schema to a clean slate.
--
-- WHAT IT TOUCHES:
--   public.*   →  everything is dropped
--
-- WHAT IT LEAVES ALONE:
--   auth.users        →  Supabase authentication accounts stay
--   storage.objects   →  uploaded files stay
--   any other schema  →  untouched
--
-- AFTER RUNNING:
--   Profiles, roles, orders, chats, regions… all gone.
--   Any super_admin you promoted needs to redo /ar/admin-setup.
--   Files uploaded to Storage buckets stay (delete via Storage UI if needed).
--
-- USAGE:
--   1) Run this whole file in Supabase Studio → SQL Editor → Run.
--   2) Immediately after, run supabase/setup.sql in the same editor.
--   3) Visit /ar/admin-setup and promote yourself again.
-- ============================================================================

begin;

-- Drop the public schema with everything in it, then recreate empty.
drop schema if exists public cascade;
create schema public;

-- Restore default grants Supabase expects on the public schema.
grant usage on schema public to anon, authenticated, service_role;
grant create on schema public to postgres, service_role;

alter default privileges in schema public
  grant all on tables to postgres, anon, authenticated, service_role;
alter default privileges in schema public
  grant all on functions to postgres, anon, authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to postgres, anon, authenticated, service_role;

-- Re-install extensions setup.sql expects. They are tied to the schema so we
-- need to recreate them explicitly even though setup.sql also uses
-- "create extension if not exists" — that succeeds either way.
create extension if not exists "pgcrypto";
create extension if not exists "pg_trgm";

commit;

-- Reminder: nothing else exists yet. Continue with supabase/setup.sql.
