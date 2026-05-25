-- Syanah · 0022 · Bootstrap activation.
--
-- On first deploy, light up the four largest regions (Riyadh, Makkah,
-- Madinah, Eastern) and their primary governorates so the public site has
-- coverage out of the box. Admins can disable any of these from
-- /admin/regions later, and the cascade triggers will follow.
--
-- This migration only flips is_active to true where it's currently false —
-- it never overrides an admin's explicit decision to disable a region.

begin;

update public.regions
   set is_active = true
 where slug in ('riyadh', 'makkah', 'madinah', 'eastern')
   and is_active = false;

-- Governorate-level activation for the top metros. The region-level cascade
-- trigger from migration 0016 already mirrors region.is_active down — but
-- only on subsequent toggles. This explicit update covers the case where
-- governorates were inserted while their region was already active.
update public.governorates
   set is_active = true
 where slug in (
   'riyadh', 'diriyah', 'kharj',
   'makkah', 'jeddah', 'taif',
   'madinah', 'yanbu',
   'dammam', 'ahsa', 'khobar', 'dhahran', 'jubail', 'qatif'
 )
   and is_active = false;

-- Mirror to their primary cities. Districts inherit is_active=true via
-- their default column value, so nothing else needs nudging.
update public.cities
   set is_active = true
 where slug in (
   'riyadh', 'diriyah', 'kharj',
   'makkah', 'jeddah', 'taif',
   'madinah', 'yanbu',
   'dammam', 'hofuf', 'mubarraz', 'khobar', 'dhahran', 'jubail', 'qatif'
 )
   and is_active = false;

commit;
