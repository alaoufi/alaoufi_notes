-- Syanah · 0007 · Seed catalog with realistic Saudi data.
-- These rows are part of the schema, not dev-only seed — they are what the platform ships with.

begin;

-- Categories (8 launch categories)

insert into public.categories (slug, name, description, icon_key, display_order) values
  ('hvac',       '{"ar":"تكييف وتبريد","en":"HVAC","ur":"اے سی","hi":"एसी","bn":"এসি"}',
                 '{"ar":"تركيب وصيانة وغسيل","en":"Install, maintain, wash"}', 'Wind', 10),
  ('plumbing',   '{"ar":"سباكة","en":"Plumbing","ur":"پلمبنگ","hi":"प्लंबिंग","bn":"প্লাম্বিং"}',
                 '{"ar":"تسرّبات، صرف، خزّانات","en":"Leaks, drains, tanks"}', 'Wrench', 20),
  ('electrical', '{"ar":"كهرباء","en":"Electrical","ur":"بجلی","hi":"बिजली","bn":"বৈদ্যুতিক"}',
                 '{"ar":"إصلاح، تمديد، لوحات","en":"Repair, wiring, panels"}', 'Zap', 30),
  ('appliances', '{"ar":"أجهزة منزلية","en":"Appliances","ur":"گھریلو آلات","hi":"घरेलू उपकरण","bn":"গৃহস্থালী"}',
                 '{"ar":"غسالات، ثلاجات، أفران","en":"Washers, fridges, ovens"}', 'WashingMachine', 40),
  ('home',       '{"ar":"صيانة عامة","en":"General","ur":"عمومی","hi":"सामान्य","bn":"সাধারণ"}',
                 '{"ar":"دهان، أبواب، جبس","en":"Paint, doors, gypsum"}', 'Home', 50),
  ('vehicle',    '{"ar":"صيانة سيارات","en":"Vehicle","ur":"گاڑی","hi":"वाहन","bn":"গাড়ি"}',
                 '{"ar":"إطارات، زيوت، بطاريات","en":"Tires, oil, battery"}', 'Car', 60),
  ('cleaning',   '{"ar":"نظافة","en":"Cleaning","ur":"صفائی","hi":"सफ़ाई","bn":"পরিষ্কার"}',
                 '{"ar":"منازل، مكاتب، فلل","en":"Homes, offices, villas"}', 'Sparkles', 70),
  ('pest',       '{"ar":"مكافحة حشرات","en":"Pest","ur":"کیڑے","hi":"कीट","bn":"কীট"}',
                 '{"ar":"رش، تعقيم","en":"Spray, sanitize"}', 'Bug', 80)
on conflict (slug) do nothing;

-- Subcategories (a few per category)

with cats as (select id, slug from public.categories)
insert into public.subcategories (category_id, slug, name, display_order)
select c.id, sc.slug, sc.name, sc.display_order
from cats c
join (values
  ('hvac', 'install',  '{"ar":"تركيب","en":"Install"}'::jsonb,           10),
  ('hvac', 'maintain', '{"ar":"صيانة","en":"Maintenance"}'::jsonb,       20),
  ('hvac', 'wash',     '{"ar":"غسيل","en":"Wash"}'::jsonb,                30),
  ('plumbing', 'leak',  '{"ar":"إصلاح تسرّب","en":"Leak repair"}'::jsonb,  10),
  ('plumbing', 'drain', '{"ar":"تسليك صرف","en":"Drain unclog"}'::jsonb,   20),
  ('plumbing', 'tank',  '{"ar":"خزّانات","en":"Water tanks"}'::jsonb,      30),
  ('electrical', 'repair', '{"ar":"إصلاح أعطال","en":"Repairs"}'::jsonb,    10),
  ('electrical', 'wiring', '{"ar":"تمديد","en":"Wiring"}'::jsonb,           20),
  ('electrical', 'panel',  '{"ar":"لوحات","en":"Panels"}'::jsonb,           30),
  ('appliances', 'washer', '{"ar":"غسالات","en":"Washing machines"}'::jsonb, 10),
  ('appliances', 'fridge', '{"ar":"ثلاجات","en":"Refrigerators"}'::jsonb,    20),
  ('appliances', 'oven',   '{"ar":"أفران","en":"Ovens"}'::jsonb,             30),
  ('home', 'paint',  '{"ar":"دهان","en":"Painting"}'::jsonb,                  10),
  ('home', 'door',   '{"ar":"أبواب","en":"Doors"}'::jsonb,                    20),
  ('home', 'gypsum', '{"ar":"جبس","en":"Gypsum"}'::jsonb,                     30),
  ('vehicle', 'oil',     '{"ar":"تغيير زيت","en":"Oil change"}'::jsonb,        10),
  ('vehicle', 'tires',   '{"ar":"إطارات","en":"Tires"}'::jsonb,                20),
  ('vehicle', 'battery', '{"ar":"بطّاريات","en":"Battery"}'::jsonb,            30),
  ('cleaning', 'home',   '{"ar":"تنظيف منازل","en":"Home cleaning"}'::jsonb,    10),
  ('cleaning', 'sofa',   '{"ar":"تنظيف كنب","en":"Sofa cleaning"}'::jsonb,      20),
  ('cleaning', 'office', '{"ar":"تنظيف مكاتب","en":"Office cleaning"}'::jsonb,  30),
  ('pest', 'roach',     '{"ar":"صراصير","en":"Cockroaches"}'::jsonb, 10),
  ('pest', 'rodents',   '{"ar":"قوارض","en":"Rodents"}'::jsonb,      20),
  ('pest', 'sanitize',  '{"ar":"تعقيم","en":"Sanitization"}'::jsonb, 30)
) as sc(cat_slug, slug, name, display_order) on sc.cat_slug = c.slug
on conflict (category_id, slug) do nothing;

-- Cities (top 14 by population)

insert into public.cities (slug, name, region, display_order) values
  ('riyadh',  '{"ar":"الرياض","en":"Riyadh"}',     'Riyadh',         10),
  ('jeddah',  '{"ar":"جدّة","en":"Jeddah"}',       'Makkah',         20),
  ('makkah',  '{"ar":"مكة المكرّمة","en":"Makkah"}','Makkah',         30),
  ('madinah', '{"ar":"المدينة المنورة","en":"Madinah"}','Madinah',    40),
  ('dammam',  '{"ar":"الدمام","en":"Dammam"}',     'Eastern',        50),
  ('khobar',  '{"ar":"الخبر","en":"Khobar"}',      'Eastern',        60),
  ('dhahran', '{"ar":"الظهران","en":"Dhahran"}',   'Eastern',        70),
  ('taif',    '{"ar":"الطائف","en":"Taif"}',       'Makkah',         80),
  ('tabuk',   '{"ar":"تبوك","en":"Tabuk"}',        'Tabuk',          90),
  ('abha',    '{"ar":"أبها","en":"Abha"}',         'Asir',          100),
  ('khamis',  '{"ar":"خميس مشيط","en":"Khamis Mushait"}','Asir',     110),
  ('hail',    '{"ar":"حائل","en":"Hail"}',         'Hail',          120),
  ('buraidah','{"ar":"بريدة","en":"Buraidah"}',    'Qassim',        130),
  ('najran',  '{"ar":"نجران","en":"Najran"}',      'Najran',        140)
on conflict (slug) do nothing;

commit;
