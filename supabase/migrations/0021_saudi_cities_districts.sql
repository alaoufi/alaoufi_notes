-- Syanah · 0021 · Saudi cities + districts seed.
--
-- Cities: one main city per governorate (the governorate seat). Major
-- governorates also get satellite cities. Districts are seeded for the
-- five largest metro areas: Riyadh, Jeddah, Makkah, Madinah, Dammam metro.

begin;

-- =========================================================================
-- 1. Cities — primarily one row per governorate, plus extra for metro areas
-- =========================================================================

-- Most governorates have their primary city sharing the governorate's
-- slug. We attach them via a single VALUES block.

with gov as (select id, slug from public.governorates)
insert into public.cities (governorate_id, slug, name, lat, lng, region, display_order)
select g.id, c.slug, c.name, c.lat, c.lng, c.region, c.display_order
from gov g
join (values
  -- Riyadh region cities
  ('riyadh','riyadh',                    '{"ar":"الرياض","en":"Riyadh","ur":"ریاض","hi":"रियाद","bn":"রিয়াদ"}'::jsonb,                       24.7136, 46.6753, 'Riyadh', 10),
  ('diriyah','diriyah',                  '{"ar":"الدرعية","en":"Diriyah","ur":"درعیہ","hi":"दिरिया","bn":"দিরিয়া"}'::jsonb,                  24.7351, 46.5750, 'Riyadh', 20),
  ('kharj','kharj',                      '{"ar":"الخرج","en":"Al-Kharj","ur":"الخرج","hi":"अल-खर्ज","bn":"আল-খারজ"}'::jsonb,                24.1554, 47.3346, 'Riyadh', 30),
  ('dawadmi','dawadmi',                  '{"ar":"الدوادمي","en":"Dawadmi","ur":"دوادمی","hi":"दवादमी","bn":"দাওয়াদমি"}'::jsonb,             24.5074, 44.3955, 'Riyadh', 40),
  ('majmaah','majmaah',                  '{"ar":"المجمعة","en":"Al-Majmaah","ur":"المجمعہ","hi":"अल-मजमाह","bn":"আল-মাজমাহ"}'::jsonb,         25.9090, 45.3500, 'Riyadh', 50),
  ('quwaiyah','quwaiyah',                '{"ar":"القويعية","en":"Quwaiyah","ur":"قویعیہ","hi":"क़ुवैया","bn":"কুওয়াইয়া"}'::jsonb,             24.0617, 45.2632, 'Riyadh', 60),
  ('wadi-dawasir','wadi-dawasir',        '{"ar":"وادي الدواسر","en":"Wadi ad-Dawasir","ur":"وادی الدواسر","hi":"वादी अद-दवासर","bn":"ওয়াদি আদ-দাওয়াসির"}'::jsonb, 20.4922, 44.8044, 'Riyadh', 70),
  ('zulfi','zulfi',                      '{"ar":"الزلفي","en":"Az-Zulfi","ur":"الزلفی","hi":"अज़-ज़ुल्फ़ी","bn":"আজ-জুলফি"}'::jsonb,           26.2982, 44.8156, 'Riyadh', 80),
  ('shaqra','shaqra',                    '{"ar":"شقراء","en":"Shaqra","ur":"شقراء","hi":"शक़रा","bn":"শাকরা"}'::jsonb,                       25.2402, 45.2569, 'Riyadh', 90),
  ('aflaj','laila',                      '{"ar":"ليلى","en":"Laila","ur":"لیلیٰ","hi":"लैला","bn":"লাইলা"}'::jsonb,                          22.2655, 46.7320, 'Riyadh', 100),

  -- Makkah region cities
  ('makkah','makkah',                    '{"ar":"مكة المكرمة","en":"Makkah","ur":"مکہ مکرمہ","hi":"मक्का","bn":"মক্কা"}'::jsonb,             21.4225, 39.8262, 'Makkah', 10),
  ('jeddah','jeddah',                    '{"ar":"جدة","en":"Jeddah","ur":"جدہ","hi":"जेद्दा","bn":"জেদ্দা"}'::jsonb,                         21.4858, 39.1925, 'Makkah', 20),
  ('taif','taif',                        '{"ar":"الطائف","en":"Taif","ur":"طائف","hi":"ताइफ़","bn":"তাইফ"}'::jsonb,                          21.2854, 40.4183, 'Makkah', 30),
  ('qunfudhah','qunfudhah',              '{"ar":"القنفذة","en":"Al-Qunfudhah","ur":"القنفذہ","hi":"अल-क़ुनफ़ुधा","bn":"আল-কুনফুধা"}'::jsonb, 19.1264, 41.0796, 'Makkah', 40),
  ('rabigh','rabigh',                    '{"ar":"رابغ","en":"Rabigh","ur":"رابغ","hi":"राबिग़","bn":"রাবিগ"}'::jsonb,                        22.7986, 39.0349, 'Makkah', 50),

  -- Madinah region cities
  ('madinah','madinah',                  '{"ar":"المدينة المنورة","en":"Madinah","ur":"مدینہ","hi":"मदीना","bn":"মদিনা"}'::jsonb,           24.4686, 39.6142, 'Madinah', 10),
  ('yanbu','yanbu',                      '{"ar":"ينبع","en":"Yanbu","ur":"ینبع","hi":"यनबू","bn":"ইয়ানবু"}'::jsonb,                          24.0894, 38.0617, 'Madinah', 20),
  ('ula','ula',                          '{"ar":"العلا","en":"Al-Ula","ur":"العلا","hi":"अल-उला","bn":"আল-উলা"}'::jsonb,                     26.6097, 37.9128, 'Madinah', 30),

  -- Eastern Province cities
  ('dammam','dammam',                    '{"ar":"الدمام","en":"Dammam","ur":"دمام","hi":"दम्माम","bn":"দাম্মাম"}'::jsonb,                   26.4207, 50.0888, 'Eastern', 10),
  ('ahsa','hofuf',                       '{"ar":"الهفوف","en":"Hofuf","ur":"ہفوف","hi":"होफ़ूफ़","bn":"হোফুফ"}'::jsonb,                      25.3833, 49.5867, 'Eastern', 20),
  ('ahsa','mubarraz',                    '{"ar":"المبرز","en":"Al-Mubarraz","ur":"مبرز","hi":"अल-मुबर्रज़","bn":"আল-মুবাররাজ"}'::jsonb,        25.4111, 49.5811, 'Eastern', 25),
  ('hafr-batin','hafr-batin',            '{"ar":"حفر الباطن","en":"Hafr al-Batin","ur":"حفر الباطن","hi":"हफ़र अल-बातिन","bn":"হাফর আল-বাতিন"}'::jsonb, 28.4338, 45.9601, 'Eastern', 30),
  ('jubail','jubail',                    '{"ar":"الجبيل","en":"Jubail","ur":"جبیل","hi":"जुबैल","bn":"জুবাইল"}'::jsonb,                     27.0046, 49.6603, 'Eastern', 40),
  ('qatif','qatif',                      '{"ar":"القطيف","en":"Qatif","ur":"قطیف","hi":"क़तीफ़","bn":"কাতিফ"}'::jsonb,                       26.5658, 49.9962, 'Eastern', 50),
  ('khobar','khobar',                    '{"ar":"الخبر","en":"Khobar","ur":"خبر","hi":"ख़ोबर","bn":"খোবার"}'::jsonb,                       26.2172, 50.1971, 'Eastern', 60),
  ('dhahran','dhahran',                  '{"ar":"الظهران","en":"Dhahran","ur":"ظہران","hi":"धहरान","bn":"ধাহরান"}'::jsonb,                  26.2361, 50.0393, 'Eastern', 70),

  -- Asir cities
  ('abha','abha',                        '{"ar":"أبها","en":"Abha","ur":"ابہا","hi":"अभा","bn":"আবহা"}'::jsonb,                              18.2167, 42.5053, 'Asir', 10),
  ('khamis-mushait','khamis-mushait',    '{"ar":"خميس مشيط","en":"Khamis Mushait","ur":"خمیس مشیط","hi":"ख़मीस मुशैत","bn":"খামিস মুশাইত"}'::jsonb, 18.3000, 42.7333, 'Asir', 20),
  ('bisha','bisha',                      '{"ar":"بيشة","en":"Bisha","ur":"بیشہ","hi":"बीशा","bn":"বিশা"}'::jsonb,                            20.0000, 42.6000, 'Asir', 30),

  -- Qassim cities
  ('buraidah','buraidah',                '{"ar":"بريدة","en":"Buraidah","ur":"بریدہ","hi":"बुरैदा","bn":"বুরাইদা"}'::jsonb,                  26.3260, 43.9750, 'Qassim', 10),
  ('unaizah','unaizah',                  '{"ar":"عنيزة","en":"Unaizah","ur":"عنیزہ","hi":"उनैज़ा","bn":"উনাইজা"}'::jsonb,                    26.0844, 43.9961, 'Qassim', 20),
  ('rass','rass',                        '{"ar":"الرس","en":"Ar-Rass","ur":"الرس","hi":"अर-रस","bn":"আর-রাস"}'::jsonb,                       25.8721, 43.5012, 'Qassim', 30),

  -- Tabuk cities
  ('tabuk','tabuk',                      '{"ar":"تبوك","en":"Tabuk","ur":"تبوک","hi":"तबूक","bn":"তাবুক"}'::jsonb,                          28.3835, 36.5662, 'Tabuk', 10),
  ('umluj','umluj',                      '{"ar":"أملج","en":"Umluj","ur":"املج","hi":"उमलज","bn":"উমলজ"}'::jsonb,                            25.0345, 37.2691, 'Tabuk', 20),

  -- Hail cities
  ('hail','hail',                        '{"ar":"حائل","en":"Hail","ur":"حائل","hi":"हाइल","bn":"হাইল"}'::jsonb,                            27.5114, 41.6900, 'Hail', 10),

  -- Northern Borders
  ('arar','arar',                        '{"ar":"عرعر","en":"Arar","ur":"عرعر","hi":"अरार","bn":"আরার"}'::jsonb,                            30.9753, 41.0214, 'Northern Borders', 10),
  ('rafha','rafha',                      '{"ar":"رفحاء","en":"Rafha","ur":"رفحاء","hi":"रफ़हा","bn":"রাফহা"}'::jsonb,                       29.6202, 43.4915, 'Northern Borders', 20),

  -- Jazan
  ('jazan','jazan',                      '{"ar":"جازان","en":"Jazan","ur":"جازان","hi":"जाज़ान","bn":"জাজান"}'::jsonb,                       16.8892, 42.5611, 'Jazan', 10),
  ('sabya','sabya',                      '{"ar":"صبيا","en":"Sabya","ur":"صبیا","hi":"सबया","bn":"সাবিয়া"}'::jsonb,                          17.1500, 42.6256, 'Jazan', 20),

  -- Najran
  ('najran','najran',                    '{"ar":"نجران","en":"Najran","ur":"نجران","hi":"नजरान","bn":"নাজরান"}'::jsonb,                     17.5656, 44.2289, 'Najran', 10),
  ('sharurah','sharurah',                '{"ar":"شرورة","en":"Sharurah","ur":"شرورہ","hi":"शरूरा","bn":"শারুরা"}'::jsonb,                  17.4869, 47.1167, 'Najran', 20),

  -- Bahah
  ('bahah','bahah',                      '{"ar":"الباحة","en":"Al-Bahah","ur":"الباحہ","hi":"अल-बाहा","bn":"আল-বাহা"}'::jsonb,             20.0129, 41.4677, 'Bahah', 10),
  ('baljurashi','baljurashi',            '{"ar":"بلجرشي","en":"Baljurashi","ur":"بلجرشی","hi":"बलजुर्शी","bn":"বলজুরাশি"}'::jsonb,         19.8581, 41.5594, 'Bahah', 20),

  -- Jouf
  ('sakaka','sakaka',                    '{"ar":"سكاكا","en":"Sakaka","ur":"سکاکا","hi":"सकाका","bn":"সাকাকা"}'::jsonb,                    29.9697, 40.2064, 'Jouf', 10),
  ('qurayyat','qurayyat',                '{"ar":"القريات","en":"Qurayyat","ur":"القریات","hi":"क़ुरैयात","bn":"কুরাইয়াত"}'::jsonb,           31.3322, 37.3431, 'Jouf', 20),
  ('dumat-jandal','dumat-jandal',        '{"ar":"دومة الجندل","en":"Dumat al-Jandal","ur":"دومۃ الجندل","hi":"दूमत अल-जंदल","bn":"দুমাত আল-জানদাল"}'::jsonb, 29.8128, 39.8636, 'Jouf', 30)
) as c(governorate_slug, slug, name, lat, lng, region, display_order) on c.governorate_slug = g.slug
on conflict (slug) do update set
  governorate_id = excluded.governorate_id,
  name = excluded.name,
  lat = excluded.lat,
  lng = excluded.lng,
  display_order = excluded.display_order;

-- =========================================================================
-- 2. Districts — for the five largest metros
-- =========================================================================

-- Riyadh districts
with city as (select id from public.cities where slug = 'riyadh' limit 1)
insert into public.districts (city_id, slug, name, lat, lng, display_order)
select (select id from city), d.slug, d.name, d.lat, d.lng, d.display_order
from (values
  ('olaya',          '{"ar":"العليا","en":"Olaya","ur":"العلیا","hi":"ओलाया","bn":"ওলায়া"}'::jsonb,                     24.6907, 46.6796, 10),
  ('diplomatic',     '{"ar":"الحي الدبلوماسي","en":"Diplomatic Quarter","ur":"سفارتی کوارٹر","hi":"डिप्लोमैटिक क्वार्टर","bn":"কূটনৈতিক কোয়ার্টার"}'::jsonb, 24.6843, 46.6219, 20),
  ('nakheel',        '{"ar":"النخيل","en":"An-Nakheel","ur":"النخیل","hi":"अन-नखील","bn":"আন-নাখিল"}'::jsonb,           24.7558, 46.6373, 30),
  ('yasmin',         '{"ar":"الياسمين","en":"Yasmin","ur":"یاسمین","hi":"यासमीन","bn":"ইয়াসমিন"}'::jsonb,                24.8344, 46.6376, 40),
  ('malqa',          '{"ar":"الملقا","en":"Al-Malqa","ur":"الملقا","hi":"अल-मलक़ा","bn":"আল-মালকা"}'::jsonb,               24.8228, 46.6358, 50),
  ('hittin',         '{"ar":"حطين","en":"Hittin","ur":"حطین","hi":"हिट्टीन","bn":"হিত্তিন"}'::jsonb,                       24.7794, 46.6431, 60),
  ('sulaimaniyah',   '{"ar":"السليمانية","en":"Sulaimaniyah","ur":"سلیمانیہ","hi":"सुलैमानिया","bn":"সুলাইমানিয়া"}'::jsonb, 24.6900, 46.7100, 70),
  ('aziziyah',       '{"ar":"العزيزية","en":"Aziziyah","ur":"عزیزیہ","hi":"अज़ीज़िया","bn":"আজিজিয়া"}'::jsonb,           24.5944, 46.7458, 80),
  ('worud',          '{"ar":"الورود","en":"Al-Worud","ur":"الورود","hi":"अल-वोरूद","bn":"আল-ওরুদ"}'::jsonb,               24.7286, 46.6772, 90),
  ('murabba',        '{"ar":"المربع","en":"Al-Murabba","ur":"المربع","hi":"अल-मुरब्बा","bn":"আল-মুরাব্বা"}'::jsonb,         24.6515, 46.7188, 100),
  ('batha',          '{"ar":"البطحاء","en":"Al-Batha","ur":"البطحاء","hi":"अल-बथा","bn":"আল-বাথা"}'::jsonb,                 24.6311, 46.7136, 110),
  ('manfuhah',       '{"ar":"منفوحة","en":"Manfuhah","ur":"منفوحہ","hi":"मनफूहा","bn":"মানফুহা"}'::jsonb,                  24.6175, 46.7322, 120),
  ('murouj',         '{"ar":"المروج","en":"Al-Murouj","ur":"المروج","hi":"अल-मुरूज","bn":"আল-মুরুজ"}'::jsonb,             24.7406, 46.6469, 130),
  ('rabwa',          '{"ar":"الربوة","en":"Ar-Rabwa","ur":"الربوہ","hi":"अर-रब्वा","bn":"আর-রাব্বা"}'::jsonb,             24.7250, 46.7300, 140),
  ('roda',           '{"ar":"الروضة","en":"Ar-Roda","ur":"الروضہ","hi":"अर-रौदा","bn":"আর-রৌদা"}'::jsonb,                  24.7000, 46.7833, 150),
  ('sahafah',        '{"ar":"الصحافة","en":"As-Sahafah","ur":"الصحافہ","hi":"अस-सहाफा","bn":"আস-সাহাফা"}'::jsonb,         24.8056, 46.6403, 160),
  ('tuwaiq',         '{"ar":"طويق","en":"Tuwaiq","ur":"طویق","hi":"तुवैक़","bn":"তুওয়াইক"}'::jsonb,                       24.6789, 46.5742, 170),
  ('suwaidi',        '{"ar":"السويدي","en":"As-Suwaidi","ur":"السویدی","hi":"अस-सुवैदी","bn":"আস-সুওয়াইদি"}'::jsonb,    24.6044, 46.6533, 180),
  ('shifa',          '{"ar":"الشفا","en":"Ash-Shifa","ur":"الشفا","hi":"अश-शिफा","bn":"আশ-শিফা"}'::jsonb,                 24.5500, 46.6736, 190),
  ('faisaliyah',     '{"ar":"الفيصلية","en":"Al-Faisaliyah","ur":"الفیصلیہ","hi":"अल-फ़ैसलिया","bn":"আল-ফাইসালিয়া"}'::jsonb, 24.6750, 46.6889, 200),
  ('rawdah',         '{"ar":"الروضة","en":"Ar-Rawdah","ur":"الروضہ","hi":"अर-रावदा","bn":"আর-রাওদা"}'::jsonb,             24.7100, 46.7800, 210),
  ('izdihar',        '{"ar":"الازدهار","en":"Al-Izdihar","ur":"الازدہار","hi":"अल-इज़दिहार","bn":"আল-ইজদিহার"}'::jsonb,    24.7339, 46.7322, 220),
  ('khaleej',        '{"ar":"الخليج","en":"Al-Khaleej","ur":"الخلیج","hi":"अल-ख़लीज","bn":"আল-খালিজ"}'::jsonb,            24.7700, 46.7800, 230),
  ('rayyan',         '{"ar":"الريان","en":"Ar-Rayyan","ur":"الریان","hi":"अर-रय्यान","bn":"আর-রাইয়ান"}'::jsonb,         24.6800, 46.8000, 240),
  ('naseem',         '{"ar":"النسيم","en":"An-Naseem","ur":"النسیم","hi":"अन-नसीम","bn":"আন-নাসিম"}'::jsonb,             24.7900, 46.7300, 250),
  ('arqah',          '{"ar":"عرقة","en":"Arqah","ur":"عرقہ","hi":"अरक़ा","bn":"আরকা"}'::jsonb,                            24.7361, 46.5489, 260),
  ('nafel',          '{"ar":"النفل","en":"An-Nafel","ur":"النفل","hi":"अन-नफ़ल","bn":"আন-নাফল"}'::jsonb,                  24.8108, 46.6633, 270),
  ('quds',           '{"ar":"القدس","en":"Al-Quds","ur":"القدس","hi":"अल-क़ुदस","bn":"আল-কুদস"}'::jsonb,                  24.7700, 46.7000, 280),
  ('falah',          '{"ar":"الفلاح","en":"Al-Falah","ur":"الفلاح","hi":"अल-फलाह","bn":"আল-ফালাহ"}'::jsonb,               24.7900, 46.6600, 290),
  ('rahmaniyah',     '{"ar":"الرحمانية","en":"Ar-Rahmaniyah","ur":"الرحمانیہ","hi":"अर-रहमानिया","bn":"আর-রাহমানিয়া"}'::jsonb, 24.7400, 46.6300, 300)
) as d(slug, name, lat, lng, display_order)
where exists (select 1 from city)
on conflict (city_id, slug) do update set
  name = excluded.name, lat = excluded.lat, lng = excluded.lng,
  display_order = excluded.display_order;

-- Jeddah districts
with city as (select id from public.cities where slug = 'jeddah' limit 1)
insert into public.districts (city_id, slug, name, lat, lng, display_order)
select (select id from city), d.slug, d.name, d.lat, d.lng, d.display_order
from (values
  ('salama',         '{"ar":"السلامة","en":"As-Salama","ur":"السلامہ","hi":"अस-सलामा","bn":"আস-সালামা"}'::jsonb,           21.5750, 39.1500, 10),
  ('hamra',          '{"ar":"الحمراء","en":"Al-Hamra","ur":"الحمراء","hi":"अल-हम्रा","bn":"আল-হামরা"}'::jsonb,           21.5478, 39.1567, 20),
  ('shati',          '{"ar":"الشاطئ","en":"Ash-Shati","ur":"الشاطی","hi":"अश-शाती","bn":"আশ-শাতি"}'::jsonb,                21.6075, 39.1067, 30),
  ('andalus',        '{"ar":"الأندلس","en":"Al-Andalus","ur":"الأندلس","hi":"अल-अंदालुस","bn":"আল-আন্দালুস"}'::jsonb,    21.5500, 39.1500, 40),
  ('naeem',          '{"ar":"النعيم","en":"An-Naeem","ur":"النعیم","hi":"अन-नईम","bn":"আন-নাঈম"}'::jsonb,                  21.6022, 39.1453, 50),
  ('aziziyah-j',     '{"ar":"العزيزية","en":"Al-Aziziyah","ur":"عزیزیہ","hi":"अल-अज़ीज़िया","bn":"আল-আজিজিয়া"}'::jsonb, 21.5500, 39.1700, 60),
  ('safa',           '{"ar":"الصفا","en":"As-Safa","ur":"الصفا","hi":"अस-सफा","bn":"আস-সাফা"}'::jsonb,                     21.5483, 39.2233, 70),
  ('hindawiyah',     '{"ar":"الهنداوية","en":"Al-Hindawiyah","ur":"الہنداویہ","hi":"अल-हिंदावीया","bn":"আল-হিন্দাওয়িয়া"}'::jsonb, 21.5167, 39.1500, 80),
  ('balad',          '{"ar":"البلد","en":"Al-Balad","ur":"البلد","hi":"अल-बलद","bn":"আল-বালাদ"}'::jsonb,                    21.4858, 39.1925, 90),
  ('rawdah-j',       '{"ar":"الروضة","en":"Ar-Rawdah","ur":"الروضہ","hi":"अर-रवदा","bn":"আর-রাওদা"}'::jsonb,             21.5500, 39.1800, 100),
  ('naseem-j',       '{"ar":"النسيم","en":"An-Naseem","ur":"النسیم","hi":"अन-नसीम","bn":"আন-নাসিম"}'::jsonb,             21.4900, 39.2500, 110),
  ('thalabah',       '{"ar":"الثعلبة","en":"Ath-Thaalibah","ur":"الثعلبہ","hi":"अथ-थालिबा","bn":"আথ-থালিবা"}'::jsonb,    21.4670, 39.1822, 120),
  ('marwah',         '{"ar":"المروة","en":"Al-Marwah","ur":"المروہ","hi":"अल-मरवा","bn":"আল-মারওয়া"}'::jsonb,           21.6181, 39.1531, 130),
  ('khalidiya-j',    '{"ar":"الخالدية","en":"Al-Khalidiya","ur":"الخالدیہ","hi":"अल-ख़ालिदिया","bn":"আল-খালিদিয়া"}'::jsonb, 21.5547, 39.1953, 140),
  ('faisaliya-j',    '{"ar":"الفيصلية","en":"Al-Faisaliya","ur":"الفیصلیہ","hi":"अल-फ़ैसलिया","bn":"আল-ফাইসালিয়া"}'::jsonb, 21.5800, 39.1800, 150),
  ('rabwa-j',        '{"ar":"الربوة","en":"Ar-Rabwa","ur":"الربوہ","hi":"अर-रब्वा","bn":"আর-রাব্বা"}'::jsonb,             21.5600, 39.1900, 160),
  ('rehab',          '{"ar":"الرحاب","en":"Ar-Rehab","ur":"الرحاب","hi":"अर-रिहाब","bn":"আর-রিহাব"}'::jsonb,              21.6500, 39.1300, 170),
  ('zahra',          '{"ar":"الزهراء","en":"Az-Zahra","ur":"الزہراء","hi":"अज़-ज़हरा","bn":"আজ-জাহরা"}'::jsonb,           21.5333, 39.1833, 180),
  ('sharafiyah',     '{"ar":"الشرفية","en":"Ash-Sharafiyah","ur":"الشرفیہ","hi":"अश-शराफिया","bn":"আশ-শারাফিয়া"}'::jsonb, 21.5147, 39.1844, 190),
  ('mishrifah',      '{"ar":"المشرفة","en":"Al-Mishrifah","ur":"المشرفہ","hi":"अल-मिशरिफा","bn":"আল-মিশরিফা"}'::jsonb,    21.6172, 39.1056, 200)
) as d(slug, name, lat, lng, display_order)
where exists (select 1 from city)
on conflict (city_id, slug) do update set
  name = excluded.name, lat = excluded.lat, lng = excluded.lng,
  display_order = excluded.display_order;

-- Makkah districts
with city as (select id from public.cities where slug = 'makkah' limit 1)
insert into public.districts (city_id, slug, name, lat, lng, display_order)
select (select id from city), d.slug, d.name, d.lat, d.lng, d.display_order
from (values
  ('aziziyah-m',     '{"ar":"العزيزية","en":"Al-Aziziyah","ur":"عزیزیہ","hi":"अल-अज़ीज़िया","bn":"আল-আজিজিয়া"}'::jsonb, 21.4044, 39.8842, 10),
  ('ajyad',          '{"ar":"أجياد","en":"Ajyad","ur":"اجیاد","hi":"अज्याद","bn":"আজইয়াদ"}'::jsonb,                       21.4233, 39.8200, 20),
  ('misfalah',       '{"ar":"المسفلة","en":"Al-Misfalah","ur":"المسفلہ","hi":"अल-मिस्फला","bn":"আল-মিস্ফলা"}'::jsonb,    21.4150, 39.8267, 30),
  ('sharafia-m',     '{"ar":"الشرفية","en":"Ash-Sharafia","ur":"الشرفیہ","hi":"अश-शराफिया","bn":"আশ-শারাফিয়া"}'::jsonb, 21.4133, 39.8350, 40),
  ('awali',          '{"ar":"العوالي","en":"Al-Awali","ur":"العوالی","hi":"अल-अवाली","bn":"আল-আওয়ালি"}'::jsonb,         21.3950, 39.9050, 50),
  ('zahir',          '{"ar":"الزاهر","en":"Az-Zahir","ur":"الزاہر","hi":"अज़-ज़ाहिर","bn":"আজ-জাহির"}'::jsonb,           21.4283, 39.8389, 60),
  ('shawqiyah',      '{"ar":"الشوقية","en":"Ash-Shawqiyah","ur":"الشوقیہ","hi":"अश-शौक़िया","bn":"আশ-শাওকিয়া"}'::jsonb, 21.4467, 39.8367, 70),
  ('rusayfah',       '{"ar":"الرصيفة","en":"Ar-Rusayfah","ur":"الرصیفہ","hi":"अर-रुसैफा","bn":"আর-রুসাইফা"}'::jsonb,    21.4322, 39.8456, 80),
  ('jamiah-m',       '{"ar":"الجامعة","en":"Al-Jamiah","ur":"الجامعہ","hi":"अल-जामिआ","bn":"আল-জামিয়া"}'::jsonb,         21.4419, 39.8519, 90),
  ('naseem-m',       '{"ar":"النسيم","en":"An-Naseem","ur":"النسیم","hi":"अन-नसीम","bn":"আন-নাসিম"}'::jsonb,             21.4378, 39.8264, 100),
  ('hajun',          '{"ar":"الحجون","en":"Al-Hajun","ur":"الحجون","hi":"अल-हाजुन","bn":"আল-হাজুন"}'::jsonb,             21.4322, 39.8294, 110),
  ('khansa',         '{"ar":"الخنساء","en":"Al-Khansa","ur":"الخنساء","hi":"अल-ख़न्सा","bn":"আল-খানসা"}'::jsonb,         21.4225, 39.8500, 120),
  ('naqa',           '{"ar":"النقا","en":"An-Naqa","ur":"النقا","hi":"अन-नक़ा","bn":"আন-নাকা"}'::jsonb,                   21.4072, 39.8631, 130),
  ('andalus-m',      '{"ar":"الأندلس","en":"Al-Andalus","ur":"الأندلس","hi":"अल-अंदलुस","bn":"আল-আন্দালুস"}'::jsonb,    21.4150, 39.8050, 140),
  ('mansour',        '{"ar":"المنصور","en":"Al-Mansour","ur":"المنصور","hi":"अल-मंसूर","bn":"আল-মানসুর"}'::jsonb,         21.4400, 39.8300, 150)
) as d(slug, name, lat, lng, display_order)
where exists (select 1 from city)
on conflict (city_id, slug) do update set
  name = excluded.name, lat = excluded.lat, lng = excluded.lng,
  display_order = excluded.display_order;

-- Madinah districts
with city as (select id from public.cities where slug = 'madinah' limit 1)
insert into public.districts (city_id, slug, name, lat, lng, display_order)
select (select id from city), d.slug, d.name, d.lat, d.lng, d.display_order
from (values
  ('markaziyah',     '{"ar":"المركزية","en":"Markaziyah","ur":"المرکزیہ","hi":"मरकज़िया","bn":"মারকাজিয়া"}'::jsonb,    24.4686, 39.6142, 10),
  ('awali-md',       '{"ar":"العوالي","en":"Al-Awali","ur":"العوالی","hi":"अल-अवाली","bn":"আল-আওয়ালি"}'::jsonb,         24.4400, 39.6300, 20),
  ('anbariyah',      '{"ar":"العنبرية","en":"Al-Anbariyah","ur":"العنبریہ","hi":"अल-अनबरिया","bn":"আল-আনবারিয়া"}'::jsonb, 24.4661, 39.6017, 30),
  ('quba',           '{"ar":"قباء","en":"Quba","ur":"قبا","hi":"क़ुबा","bn":"কুবা"}'::jsonb,                                24.4400, 39.6175, 40),
  ('sayyid-shuhada', '{"ar":"سيد الشهداء","en":"Sayyid Ash-Shuhada","ur":"سید الشہداء","hi":"सय्यद अश-शुहदा","bn":"সাইয়িদ আশ-শুহাদা"}'::jsonb, 24.4842, 39.6086, 50),
  ('sultanah',       '{"ar":"السلطانة","en":"Sultanah","ur":"السلطانہ","hi":"सुल्ताना","bn":"সুলতানা"}'::jsonb,            24.4700, 39.6200, 60),
  ('jurf',           '{"ar":"الجرف","en":"Al-Jurf","ur":"الجرف","hi":"अल-जुर्फ","bn":"আল-জুরফ"}'::jsonb,                  24.5300, 39.5800, 70),
  ('khalidiya-md',   '{"ar":"الخالدية","en":"Al-Khalidiya","ur":"الخالدیہ","hi":"अल-ख़ालिदिया","bn":"আল-খালিদিয়া"}'::jsonb, 24.4900, 39.6300, 80),
  ('aziziyah-md',    '{"ar":"العزيزية","en":"Al-Aziziyah","ur":"عزیزیہ","hi":"अल-अज़ीज़िया","bn":"আল-আজিজিয়া"}'::jsonb, 24.4500, 39.6500, 90),
  ('rawdah-md',      '{"ar":"الروضة","en":"Ar-Rawdah","ur":"الروضہ","hi":"अर-रवदा","bn":"আর-রাওদা"}'::jsonb,             24.4750, 39.6250, 100)
) as d(slug, name, lat, lng, display_order)
where exists (select 1 from city)
on conflict (city_id, slug) do update set
  name = excluded.name, lat = excluded.lat, lng = excluded.lng,
  display_order = excluded.display_order;

-- Dammam districts
with city as (select id from public.cities where slug = 'dammam' limit 1)
insert into public.districts (city_id, slug, name, lat, lng, display_order)
select (select id from city), d.slug, d.name, d.lat, d.lng, d.display_order
from (values
  ('faisaliyah-d',   '{"ar":"الفيصلية","en":"Al-Faisaliyah","ur":"الفیصلیہ","hi":"अल-फ़ैसलिया","bn":"আল-ফাইসালিয়া"}'::jsonb, 26.4181, 50.1042, 10),
  ('adamah',         '{"ar":"العدامة","en":"Al-Adamah","ur":"العدامہ","hi":"अल-अदामा","bn":"আল-আদামা"}'::jsonb,           26.4053, 50.1131, 20),
  ('bahir',          '{"ar":"الباحة","en":"Al-Bahir","ur":"الباحہ","hi":"अल-बाहिर","bn":"আল-বাহির"}'::jsonb,             26.4250, 50.0833, 30),
  ('shati-d',        '{"ar":"الشاطئ","en":"Ash-Shati","ur":"الشاطی","hi":"अश-शाती","bn":"আশ-শাতি"}'::jsonb,                26.4467, 50.0975, 40),
  ('aziziyah-d',     '{"ar":"العزيزية","en":"Al-Aziziyah","ur":"عزیزیہ","hi":"अल-अज़ीज़िया","bn":"আল-আজিজিয়া"}'::jsonb, 26.3500, 50.1167, 50),
  ('anwar',          '{"ar":"الأنوار","en":"Al-Anwar","ur":"الانوار","hi":"अल-अनवर","bn":"আল-আনওয়ার"}'::jsonb,            26.3833, 50.1167, 60),
  ('badi',           '{"ar":"البديع","en":"Al-Badi","ur":"البدیع","hi":"अल-बदी","bn":"আল-বাদি"}'::jsonb,                   26.3450, 50.1500, 70),
  ('manar',          '{"ar":"المنار","en":"Al-Manar","ur":"المنار","hi":"अल-मनार","bn":"আল-মানার"}'::jsonb,               26.4200, 50.1400, 80),
  ('jalawiyah',      '{"ar":"الجلوية","en":"Al-Jalawiyah","ur":"الجلویہ","hi":"अल-जलविया","bn":"আল-জালাউইয়া"}'::jsonb,    26.4100, 50.1000, 90),
  ('iskan',          '{"ar":"الإسكان","en":"Al-Iskan","ur":"الإسکان","hi":"अल-इसकान","bn":"আল-ইসকান"}'::jsonb,             26.4350, 50.0750, 100)
) as d(slug, name, lat, lng, display_order)
where exists (select 1 from city)
on conflict (city_id, slug) do update set
  name = excluded.name, lat = excluded.lat, lng = excluded.lng,
  display_order = excluded.display_order;

commit;
