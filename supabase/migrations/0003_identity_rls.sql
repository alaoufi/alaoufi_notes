-- Syanah · 0003 · RLS policies for identity tables.
-- Default policy: deny all. Explicit policies grant the minimum each role needs.

begin;

-- profiles

alter table public.profiles enable row level security;

drop policy if exists profiles_select_self_or_admin on public.profiles;
create policy profiles_select_self_or_admin
  on public.profiles for select
  to authenticated
  using (user_id = auth.uid() or public.user_is_admin(auth.uid()));

drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self
  on public.profiles for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists profiles_update_self_or_admin on public.profiles;
create policy profiles_update_self_or_admin
  on public.profiles for update
  to authenticated
  using (user_id = auth.uid() or public.user_is_admin(auth.uid()))
  with check (user_id = auth.uid() or public.user_is_admin(auth.uid()));

-- user_roles

alter table public.user_roles enable row level security;

drop policy if exists user_roles_select_self_or_admin on public.user_roles;
create policy user_roles_select_self_or_admin
  on public.user_roles for select
  to authenticated
  using (user_id = auth.uid() or public.user_is_admin(auth.uid()));

drop policy if exists user_roles_insert_super_admin on public.user_roles;
create policy user_roles_insert_super_admin
  on public.user_roles for insert
  to authenticated
  with check (public.user_has_role(auth.uid(), 'super_admin'));

drop policy if exists user_roles_delete_super_admin on public.user_roles;
create policy user_roles_delete_super_admin
  on public.user_roles for delete
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'));

-- admin_sections (super admin only)

alter table public.admin_sections enable row level security;

drop policy if exists admin_sections_select_staff on public.admin_sections;
create policy admin_sections_select_staff
  on public.admin_sections for select
  to authenticated
  using (public.user_is_admin(auth.uid()));

drop policy if exists admin_sections_write_super on public.admin_sections;
create policy admin_sections_write_super
  on public.admin_sections for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

-- section_admin_assignments

alter table public.section_admin_assignments enable row level security;

drop policy if exists assignments_select_self_or_super on public.section_admin_assignments;
create policy assignments_select_self_or_super
  on public.section_admin_assignments for select
  to authenticated
  using (section_admin_id = auth.uid() or public.user_has_role(auth.uid(), 'super_admin'));

drop policy if exists assignments_write_super on public.section_admin_assignments;
create policy assignments_write_super
  on public.section_admin_assignments for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

-- devices: user owns their devices, admins can see all

alter table public.devices enable row level security;

drop policy if exists devices_select_owner_or_admin on public.devices;
create policy devices_select_owner_or_admin
  on public.devices for select
  to authenticated
  using (user_id = auth.uid() or public.user_is_admin(auth.uid()));

drop policy if exists devices_write_owner on public.devices;
create policy devices_write_owner
  on public.devices for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- verifications: only the owner can see their own; service role (edge functions) bypasses RLS.

alter table public.verifications enable row level security;

drop policy if exists verifications_select_owner on public.verifications;
create policy verifications_select_owner
  on public.verifications for select
  to authenticated
  using (user_id = auth.uid());

-- inserts/updates of verifications go exclusively through service-role (Edge Functions), so no
-- public insert/update policy is granted here.

commit;
