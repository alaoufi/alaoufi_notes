-- Syanah · 0006 · RLS for catalog tables.
-- Read: anyone authenticated can see active rows; admins see all.
-- Write: super_admin everywhere; section_admin within their scope (enforced in higher migrations).

begin;

-- categories

alter table public.categories enable row level security;

drop policy if exists categories_read_active on public.categories;
create policy categories_read_active
  on public.categories for select
  to anon, authenticated
  using (is_active or public.user_is_admin(auth.uid()));

drop policy if exists categories_write_super on public.categories;
create policy categories_write_super
  on public.categories for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

-- subcategories

alter table public.subcategories enable row level security;

drop policy if exists subcategories_read_active on public.subcategories;
create policy subcategories_read_active
  on public.subcategories for select
  to anon, authenticated
  using (is_active or public.user_is_admin(auth.uid()));

drop policy if exists subcategories_write_super on public.subcategories;
create policy subcategories_write_super
  on public.subcategories for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

-- services

alter table public.services enable row level security;

drop policy if exists services_read_active on public.services;
create policy services_read_active
  on public.services for select
  to anon, authenticated
  using (is_active or public.user_is_admin(auth.uid()));

drop policy if exists services_write_super on public.services;
create policy services_write_super
  on public.services for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

-- cities & districts (public read, admin write)

alter table public.cities enable row level security;

drop policy if exists cities_read_active on public.cities;
create policy cities_read_active
  on public.cities for select
  to anon, authenticated
  using (is_active or public.user_is_admin(auth.uid()));

drop policy if exists cities_write_super on public.cities;
create policy cities_write_super
  on public.cities for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

alter table public.districts enable row level security;

drop policy if exists districts_read_all on public.districts;
create policy districts_read_all
  on public.districts for select
  to anon, authenticated
  using (true);

drop policy if exists districts_write_super on public.districts;
create policy districts_write_super
  on public.districts for all
  to authenticated
  using (public.user_has_role(auth.uid(), 'super_admin'))
  with check (public.user_has_role(auth.uid(), 'super_admin'));

-- providers

alter table public.providers enable row level security;

drop policy if exists providers_read_active on public.providers;
create policy providers_read_active
  on public.providers for select
  to anon, authenticated
  using (
    (is_active and is_verified)
    or user_id = auth.uid()
    or public.user_is_admin(auth.uid())
  );

drop policy if exists providers_insert_self on public.providers;
create policy providers_insert_self
  on public.providers for insert
  to authenticated
  with check (user_id = auth.uid() and public.user_has_role(auth.uid(), 'provider'));

drop policy if exists providers_update_self_or_admin on public.providers;
create policy providers_update_self_or_admin
  on public.providers for update
  to authenticated
  using (user_id = auth.uid() or public.user_is_admin(auth.uid()))
  with check (user_id = auth.uid() or public.user_is_admin(auth.uid()));

-- provider_categories

alter table public.provider_categories enable row level security;

drop policy if exists provider_categories_read_all on public.provider_categories;
create policy provider_categories_read_all
  on public.provider_categories for select
  to anon, authenticated
  using (true);

drop policy if exists provider_categories_write_self on public.provider_categories;
create policy provider_categories_write_self
  on public.provider_categories for all
  to authenticated
  using (provider_id = auth.uid() or public.user_is_admin(auth.uid()))
  with check (provider_id = auth.uid() or public.user_is_admin(auth.uid()));

-- provider_coverage_areas

alter table public.provider_coverage_areas enable row level security;

drop policy if exists coverage_read_all on public.provider_coverage_areas;
create policy coverage_read_all
  on public.provider_coverage_areas for select
  to anon, authenticated
  using (true);

drop policy if exists coverage_write_self on public.provider_coverage_areas;
create policy coverage_write_self
  on public.provider_coverage_areas for all
  to authenticated
  using (provider_id = auth.uid() or public.user_is_admin(auth.uid()))
  with check (provider_id = auth.uid() or public.user_is_admin(auth.uid()));

commit;
