-- Seed data for local dev.
-- Run with: supabase db reset (after `supabase start`)

insert into public.admin_sections (scope_type, scope_value, label)
values
  ('global', 'all', '{"ar":"كل المنصة","en":"Whole platform"}'::jsonb),
  ('category', 'hvac', '{"ar":"تكييف وتبريد","en":"HVAC"}'::jsonb),
  ('category', 'plumbing', '{"ar":"سباكة","en":"Plumbing"}'::jsonb),
  ('city', 'riyadh', '{"ar":"الرياض","en":"Riyadh"}'::jsonb),
  ('city', 'jeddah', '{"ar":"جدة","en":"Jeddah"}'::jsonb)
on conflict (scope_type, scope_value) do nothing;
