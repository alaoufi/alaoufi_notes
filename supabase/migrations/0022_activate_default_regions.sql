-- Syanah · 0022 · Bootstrap activation.
--
-- On first deploy, light up every Saudi region + its governorates + its
-- cities so the public site covers the whole kingdom out of the box.
-- Admins can disable any region/governorate from /admin/regions later;
-- the cascade triggers will mirror their decisions down to children.
--
-- This migration only flips is_active to true where it's currently false —
-- it never overrides an admin's explicit decision to disable a region.

begin;

update public.regions
   set is_active = true
 where is_active = false;

update public.governorates
   set is_active = true
 where is_active = false;

update public.cities
   set is_active = true
 where is_active = false;

update public.districts
   set is_active = true
 where is_active = false;

commit;
