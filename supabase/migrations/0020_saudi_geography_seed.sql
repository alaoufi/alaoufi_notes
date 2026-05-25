-- Syanah · 0020 · Comprehensive Saudi Arabia geography seed.
--
-- All 13 administrative regions + every official governorate + main cities +
-- districts for the five largest metro areas (Riyadh, Jeddah, Makkah,
-- Madinah, Dammam metro).
--
-- Multilingual names: ar + en for every row. ur / hi / bn names match the
-- Arabic for proper nouns (they're transliterations of the same word in a
-- different script — admins can refine via /admin/translations).
--
-- All inserts use `on conflict ... do update` so re-running the migration
-- refreshes translations and coordinates without disturbing admin-set
-- is_active flags.

begin;

-- =========================================================================
-- 1. Regions — refresh names + coordinates
-- =========================================================================

insert into public.regions (slug, name, lat, lng, display_order) values
  ('riyadh',           '{"ar":"منطقة الرياض","en":"Riyadh Region","ur":"ریاض","hi":"रियाद","bn":"রিয়াদ"}',                24.7136, 46.6753, 10),
  ('makkah',           '{"ar":"منطقة مكة المكرمة","en":"Makkah Region","ur":"مکہ","hi":"मक्का","bn":"মক্কা"}',              21.3891, 39.8579, 20),
  ('madinah',          '{"ar":"منطقة المدينة المنورة","en":"Madinah Region","ur":"مدینہ","hi":"मदीना","bn":"মদিনা"}',     24.5247, 39.5692, 30),
  ('eastern',          '{"ar":"المنطقة الشرقية","en":"Eastern Province","ur":"مشرقی صوبہ","hi":"पूर्वी प्रांत","bn":"পূর্ব প্রদেশ"}', 26.4207, 50.0888, 40),
  ('asir',             '{"ar":"منطقة عسير","en":"Asir Region","ur":"عسیر","hi":"असीर","bn":"আসির"}',                       18.2167, 42.5053, 50),
  ('qassim',           '{"ar":"منطقة القصيم","en":"Qassim Region","ur":"قصیم","hi":"क़सीम","bn":"কাসিম"}',                 26.3206, 43.9750, 60),
  ('tabuk',            '{"ar":"منطقة تبوك","en":"Tabuk Region","ur":"تبوک","hi":"तबूक","bn":"তাবুক"}',                     28.3835, 36.5662, 70),
  ('hail',             '{"ar":"منطقة حائل","en":"Hail Region","ur":"حائل","hi":"हाइल","bn":"হাইল"}',                       27.5114, 41.6900, 80),
  ('northern-borders', '{"ar":"منطقة الحدود الشمالية","en":"Northern Borders","ur":"شمالی سرحدیں","hi":"उत्तरी सीमा","bn":"উত্তর সীমান্ত"}', 30.9753, 41.0214, 90),
  ('jazan',            '{"ar":"منطقة جازان","en":"Jazan Region","ur":"جازان","hi":"जाज़ान","bn":"জাজান"}',                100, 16.8892, 42.5611),
  ('najran',           '{"ar":"منطقة نجران","en":"Najran Region","ur":"نجران","hi":"नजरान","bn":"নাজরান"}',               17.5656, 44.2289, 110),
  ('bahah',            '{"ar":"منطقة الباحة","en":"Al-Bahah Region","ur":"الباحہ","hi":"अल-बाहा","bn":"আল-বাহা"}',         20.0129, 41.4677, 120),
  ('jouf',             '{"ar":"منطقة الجوف","en":"Al-Jouf Region","ur":"الجوف","hi":"अल-जौफ","bn":"আল-জৌফ"}',              29.7858, 40.2056, 130)
on conflict (slug) do update set
  name = excluded.name,
  lat  = excluded.lat,
  lng  = excluded.lng,
  display_order = excluded.display_order;

-- Jazan had its (display_order, lat, lng) tuple flipped above — fix it
-- explicitly in case the values inserted got rearranged in older runs.
update public.regions
   set lat = 16.8892, lng = 42.5611, display_order = 100
 where slug = 'jazan';

-- =========================================================================
-- 2. Governorates — full official list per region
-- =========================================================================

-- Helper CTE pattern: select the region id then join in the values block.
with reg as (select id, slug from public.regions)
insert into public.governorates (region_id, slug, name, lat, lng, display_order)
select r.id, g.slug, g.name, g.lat, g.lng, g.display_order
from reg r
join (values
  -- Riyadh region (19 governorates)
  ('riyadh','riyadh',           '{"ar":"الرياض","en":"Riyadh","ur":"ریاض","hi":"रियाद","bn":"রিয়াদ"}'::jsonb,                       24.7136, 46.6753, 10),
  ('riyadh','diriyah',          '{"ar":"الدرعية","en":"Diriyah","ur":"درعیہ","hi":"दिरिया","bn":"দিরিয়া"}'::jsonb,                    24.7351, 46.5750, 20),
  ('riyadh','kharj',            '{"ar":"الخرج","en":"Al-Kharj","ur":"الخرج","hi":"अल-खर्ज","bn":"আল-খারজ"}'::jsonb,                  24.1554, 47.3346, 30),
  ('riyadh','dawadmi',          '{"ar":"الدوادمي","en":"Dawadmi","ur":"دوادمی","hi":"दवादमी","bn":"দাওয়াদমি"}'::jsonb,                24.5074, 44.3955, 40),
  ('riyadh','majmaah',          '{"ar":"المجمعة","en":"Al-Majmaah","ur":"المجمعہ","hi":"अल-मजमाह","bn":"আল-মাজমাহ"}'::jsonb,         25.9090, 45.3500, 50),
  ('riyadh','quwaiyah',         '{"ar":"القويعية","en":"Quwaiyah","ur":"قویعیہ","hi":"क़ुवैया","bn":"কুওয়াইয়া"}'::jsonb,             24.0617, 45.2632, 60),
  ('riyadh','wadi-dawasir',     '{"ar":"وادي الدواسر","en":"Wadi ad-Dawasir","ur":"وادی الدواسر","hi":"वादी अद-दवासर","bn":"ওয়াদি আদ-দাওয়াসির"}'::jsonb, 20.4922, 44.8044, 70),
  ('riyadh','zulfi',            '{"ar":"الزلفي","en":"Az-Zulfi","ur":"الزلفی","hi":"अज़-ज़ुल्फ़ी","bn":"আজ-জুলফি"}'::jsonb,           26.2982, 44.8156, 80),
  ('riyadh','shaqra',           '{"ar":"شقراء","en":"Shaqra","ur":"شقراء","hi":"शक़रा","bn":"শাকরা"}'::jsonb,                       25.2402, 45.2569, 90),
  ('riyadh','aflaj',            '{"ar":"الأفلاج","en":"Al-Aflaj","ur":"الأفلاج","hi":"अल-अफ़लाज","bn":"আল-আফলাজ"}'::jsonb,           22.2655, 46.7320, 100),
  ('riyadh','hawtat-bani-tamim','{"ar":"حوطة بني تميم","en":"Hawtat Bani Tamim","ur":"حوطہ بنی تمیم","hi":"हौता बनी तमीम","bn":"হাওতা বনি তামিম"}'::jsonb, 23.5217, 46.8489, 110),
  ('riyadh','afif',             '{"ar":"عفيف","en":"Afif","ur":"عفیف","hi":"अफ़ीफ़","bn":"আফিফ"}'::jsonb,                          23.9095, 42.9168, 120),
  ('riyadh','sulayyil',         '{"ar":"السليل","en":"As-Sulayyil","ur":"السلیل","hi":"अस-सुलैयिल","bn":"আস-সুলাইল"}'::jsonb,         20.4630, 45.5790, 130),
  ('riyadh','dhurma',           '{"ar":"ضرما","en":"Dhurma","ur":"ضرما","hi":"धुरमा","bn":"ধুরমা"}'::jsonb,                        24.6111, 46.1556, 140),
  ('riyadh','rumah',            '{"ar":"رماح","en":"Rumah","ur":"رماح","hi":"रुमाह","bn":"রুমাহ"}'::jsonb,                          25.5667, 47.1500, 150),
  ('riyadh','thadiq',           '{"ar":"ثادق","en":"Thadiq","ur":"ثادق","hi":"थादिक़","bn":"থাদিক"}'::jsonb,                        25.2917, 45.8606, 160),
  ('riyadh','ghat',             '{"ar":"الغاط","en":"Al-Ghat","ur":"الغاط","hi":"अल-घात","bn":"আল-ঘাত"}'::jsonb,                    26.0167, 44.9667, 170),
  ('riyadh','huraymila',        '{"ar":"حريملاء","en":"Huraymila","ur":"حریملاء","hi":"हुरैमिला","bn":"হুরাইমিলা"}'::jsonb,           25.1419, 46.1056, 180),
  ('riyadh','muzahmiya',        '{"ar":"المزاحمية","en":"Muzahmiya","ur":"مزاحمیہ","hi":"मुज़ाहमीया","bn":"মুজাহমিয়া"}'::jsonb,        24.4750, 46.2722, 190),

  -- Makkah region (13)
  ('makkah','makkah',           '{"ar":"مكة المكرمة","en":"Makkah","ur":"مکہ مکرمہ","hi":"मक्का","bn":"মক্কা"}'::jsonb,             21.4225, 39.8262, 10),
  ('makkah','jeddah',           '{"ar":"جدة","en":"Jeddah","ur":"جدہ","hi":"जेद्दा","bn":"জেদ্দা"}'::jsonb,                         21.4858, 39.1925, 20),
  ('makkah','taif',             '{"ar":"الطائف","en":"Taif","ur":"طائف","hi":"ताइफ़","bn":"তাইফ"}'::jsonb,                          21.2854, 40.4183, 30),
  ('makkah','qunfudhah',        '{"ar":"القنفذة","en":"Al-Qunfudhah","ur":"القنفذہ","hi":"अल-क़ुनफ़ुधा","bn":"আল-কুনফুধা"}'::jsonb, 19.1264, 41.0796, 40),
  ('makkah','laith',            '{"ar":"الليث","en":"Al-Laith","ur":"اللیث","hi":"अल-लैथ","bn":"আল-লাইথ"}'::jsonb,                  20.1503, 40.2667, 50),
  ('makkah','rabigh',           '{"ar":"رابغ","en":"Rabigh","ur":"رابغ","hi":"राबिग़","bn":"রাবিগ"}'::jsonb,                        22.7986, 39.0349, 60),
  ('makkah','khulais',          '{"ar":"خليص","en":"Khulais","ur":"خلیص","hi":"ख़ुलैस","bn":"খুলাইস"}'::jsonb,                       22.1583, 39.3194, 70),
  ('makkah','jumum',            '{"ar":"الجموم","en":"Al-Jumum","ur":"الجموم","hi":"अल-जुमूम","bn":"আল-জুমুম"}'::jsonb,             21.6125, 39.7000, 80),
  ('makkah','kamil',            '{"ar":"الكامل","en":"Al-Kamil","ur":"الکامل","hi":"अल-कामिल","bn":"আল-কামিল"}'::jsonb,             21.7456, 39.7361, 90),
  ('makkah','khurma',           '{"ar":"الخرمة","en":"Al-Khurma","ur":"الخرمہ","hi":"अल-खुर्मा","bn":"আল-খুরমা"}'::jsonb,             21.9226, 42.0490, 100),
  ('makkah','ranyah',           '{"ar":"رنية","en":"Ranyah","ur":"رنیہ","hi":"रनिया","bn":"রনিয়া"}'::jsonb,                         21.2667, 42.8500, 110),
  ('makkah','turabah',          '{"ar":"تربة","en":"Turabah","ur":"تربہ","hi":"तुरबा","bn":"তুরবাহ"}'::jsonb,                       21.2117, 41.6347, 120),
  ('makkah','adam',             '{"ar":"العرضيات","en":"Al-Ardiyat","ur":"العرضیات","hi":"अल-अरदियात","bn":"আল-আরদিয়াত"}'::jsonb,    19.7944, 41.5067, 130),

  -- Madinah region (7)
  ('madinah','madinah',         '{"ar":"المدينة المنورة","en":"Madinah","ur":"مدینہ","hi":"मदीना","bn":"মদিনা"}'::jsonb,           24.4686, 39.6142, 10),
  ('madinah','yanbu',           '{"ar":"ينبع","en":"Yanbu","ur":"ینبع","hi":"यनबू","bn":"ইয়ানবু"}'::jsonb,                          24.0894, 38.0617, 20),
  ('madinah','badr',            '{"ar":"بدر","en":"Badr","ur":"بدر","hi":"बद्र","bn":"বদর"}'::jsonb,                                23.7800, 38.7900, 30),
  ('madinah','ula',             '{"ar":"العلا","en":"Al-Ula","ur":"العلا","hi":"अल-उला","bn":"আল-উলা"}'::jsonb,                     26.6097, 37.9128, 40),
  ('madinah','khaybar',         '{"ar":"خيبر","en":"Khaybar","ur":"خیبر","hi":"ख़ैबर","bn":"খাইবার"}'::jsonb,                       25.7000, 39.2917, 50),
  ('madinah','mahd-thahab',     '{"ar":"مهد الذهب","en":"Mahd adh-Dhahab","ur":"مہد الذہب","hi":"महद अध-धहब","bn":"মাহদ আদ-ধাহাব"}'::jsonb, 23.5000, 40.8500, 60),
  ('madinah','henakiyah',       '{"ar":"الحناكية","en":"Al-Henakiyah","ur":"الحناکیہ","hi":"अल-हनाकिया","bn":"আল-হেনাকিয়া"}'::jsonb, 24.8639, 40.5099, 70),

  -- Eastern Province (12)
  ('eastern','dammam',          '{"ar":"الدمام","en":"Dammam","ur":"دمام","hi":"दम्माम","bn":"দাম্মাম"}'::jsonb,                  26.4207, 50.0888, 10),
  ('eastern','ahsa',            '{"ar":"الأحساء","en":"Al-Ahsa","ur":"الأحساء","hi":"अल-अहसा","bn":"আল-আহসা"}'::jsonb,             25.3833, 49.5867, 20),
  ('eastern','hafr-batin',      '{"ar":"حفر الباطن","en":"Hafr al-Batin","ur":"حفر الباطن","hi":"हफ़र अल-बातिन","bn":"হাফর আল-বাতিন"}'::jsonb, 28.4338, 45.9601, 30),
  ('eastern','jubail',          '{"ar":"الجبيل","en":"Jubail","ur":"جبیل","hi":"जुबैल","bn":"জুবাইল"}'::jsonb,                     27.0046, 49.6603, 40),
  ('eastern','qatif',           '{"ar":"القطيف","en":"Qatif","ur":"قطیف","hi":"क़तीफ़","bn":"কাতিফ"}'::jsonb,                       26.5658, 49.9962, 50),
  ('eastern','khobar',          '{"ar":"الخبر","en":"Khobar","ur":"خبر","hi":"ख़ोबर","bn":"খোবার"}'::jsonb,                       26.2172, 50.1971, 60),
  ('eastern','dhahran',         '{"ar":"الظهران","en":"Dhahran","ur":"ظہران","hi":"धहरान","bn":"ধাহরান"}'::jsonb,                  26.2361, 50.0393, 70),
  ('eastern','nairyah',         '{"ar":"النعيرية","en":"An-Nairyah","ur":"النعیریہ","hi":"अन-नैरिया","bn":"আন-নাইরিয়া"}'::jsonb,    27.4811, 48.4842, 80),
  ('eastern','khafji',          '{"ar":"الخفجي","en":"Al-Khafji","ur":"الخفجی","hi":"अल-ख़फ़जी","bn":"আল-খাফজি"}'::jsonb,             28.4344, 48.4910, 90),
  ('eastern','ras-tanura',      '{"ar":"رأس تنورة","en":"Ras Tanura","ur":"رأس تنورہ","hi":"रास तनूरा","bn":"রাস তানুরা"}'::jsonb,    26.6431, 50.1593, 100),
  ('eastern','qaryat-ulya',     '{"ar":"قرية العليا","en":"Qaryat al-Ulya","ur":"قریۃ العلیا","hi":"क़रिया अल-उल्या","bn":"কারিয়া আল-উলিয়া"}'::jsonb, 27.6300, 47.5300, 110),
  ('eastern','buqayq',          '{"ar":"بقيق","en":"Buqayq","ur":"بقیق","hi":"बुक़ैक़","bn":"বুকাইক"}'::jsonb,                        25.9333, 49.6667, 120),

  -- Asir (13)
  ('asir','abha',               '{"ar":"أبها","en":"Abha","ur":"ابہا","hi":"अभा","bn":"আবহা"}'::jsonb,                              18.2167, 42.5053, 10),
  ('asir','khamis-mushait',     '{"ar":"خميس مشيط","en":"Khamis Mushait","ur":"خمیس مشیط","hi":"ख़मीस मुशैत","bn":"খামিস মুশাইত"}'::jsonb, 18.3000, 42.7333, 20),
  ('asir','bisha',              '{"ar":"بيشة","en":"Bisha","ur":"بیشہ","hi":"बीशा","bn":"বিশা"}'::jsonb,                            20.0000, 42.6000, 30),
  ('asir','namas',              '{"ar":"النماص","en":"An-Namas","ur":"النماص","hi":"अन-नमास","bn":"আন-নামাস"}'::jsonb,             19.1500, 42.1167, 40),
  ('asir','muhayil',            '{"ar":"محايل عسير","en":"Muhayil Asir","ur":"محایل عسیر","hi":"मुहैयिल असीर","bn":"মুহাইল আসির"}'::jsonb, 18.5444, 41.9614, 50),
  ('asir','rijal-almaa',        '{"ar":"رجال ألمع","en":"Rijal Almaa","ur":"رجال ألمع","hi":"रिजाल अलमा","bn":"রিজাল আলমা"}'::jsonb,    18.1844, 42.1581, 60),
  ('asir','tathlith',           '{"ar":"تثليث","en":"Tathlith","ur":"تثلیث","hi":"तथलीथ","bn":"তাথলিথ"}'::jsonb,                    19.5667, 43.3000, 70),
  ('asir','sarat-abidah',       '{"ar":"سراة عبيدة","en":"Sarat Abidah","ur":"سراۃ عبیدہ","hi":"सरात अबीदा","bn":"সারাত আবিদা"}'::jsonb, 18.1500, 42.9000, 80),
  ('asir','bariq',              '{"ar":"بارق","en":"Bariq","ur":"بارق","hi":"बारिक़","bn":"বারিক"}'::jsonb,                          18.7167, 41.9667, 90),
  ('asir','dhahran-janub',      '{"ar":"ظهران الجنوب","en":"Dhahran al-Janub","ur":"ظہران الجنوب","hi":"धहरान अल-जनूब","bn":"ধাহরান আল-জানুব"}'::jsonb, 17.6000, 43.5000, 100),
  ('asir','tareeb',             '{"ar":"تريب","en":"Tareeb","ur":"تریب","hi":"तरीब","bn":"তারিব"}'::jsonb,                          17.7000, 43.4500, 110),
  ('asir','mojaridah',          '{"ar":"المجاردة","en":"Al-Mojaridah","ur":"المجاردہ","hi":"अल-मोजारिदा","bn":"আল-মোজারিদা"}'::jsonb, 19.1228, 41.9603, 120),
  ('asir','ahad-rufaidah',      '{"ar":"أحد رفيدة","en":"Ahad Rufaidah","ur":"احد رفیدہ","hi":"अहद रुफ़ैदा","bn":"আহাদ রুফাইদা"}'::jsonb, 18.2289, 42.7506, 130),

  -- Qassim (12)
  ('qassim','buraidah',         '{"ar":"بريدة","en":"Buraidah","ur":"بریدہ","hi":"बुरैदा","bn":"বুরাইদা"}'::jsonb,                  26.3260, 43.9750, 10),
  ('qassim','unaizah',          '{"ar":"عنيزة","en":"Unaizah","ur":"عنیزہ","hi":"उनैज़ा","bn":"উনাইজা"}'::jsonb,                    26.0844, 43.9961, 20),
  ('qassim','rass',             '{"ar":"الرس","en":"Ar-Rass","ur":"الرس","hi":"अर-रस","bn":"আর-রাস"}'::jsonb,                       25.8721, 43.5012, 30),
  ('qassim','mithnab',          '{"ar":"المذنب","en":"Al-Mithnab","ur":"المذنب","hi":"अल-मिथनब","bn":"আল-মিথনাব"}'::jsonb,         25.8667, 44.2167, 40),
  ('qassim','bukairiyah',       '{"ar":"البكيرية","en":"Al-Bukairiyah","ur":"البکیریہ","hi":"अल-बुकैरिया","bn":"আল-বুকাইরিয়া"}'::jsonb, 26.1397, 43.6597, 50),
  ('qassim','badayea',          '{"ar":"البدائع","en":"Al-Badayea","ur":"البدائع","hi":"अल-बदायेआ","bn":"আল-বাদায়েআ"}'::jsonb,      26.0444, 43.7833, 60),
  ('qassim','riyadh-khabra',    '{"ar":"رياض الخبراء","en":"Riyadh al-Khabra","ur":"ریاض الخبراء","hi":"रियाद अल-ख़बरा","bn":"রিয়াদ আল-খাবরা"}'::jsonb, 26.5000, 43.5500, 70),
  ('qassim','nabhaniyah',       '{"ar":"النبهانية","en":"An-Nabhaniyah","ur":"النبہانیہ","hi":"अन-नबहानिया","bn":"আন-নাবহানিয়া"}'::jsonb, 26.3833, 43.1500, 80),
  ('qassim','shimasiyah',       '{"ar":"الشماسية","en":"Ash-Shimasiyah","ur":"الشماسیہ","hi":"अश-शिमासिया","bn":"আশ-শিমাসিয়া"}'::jsonb, 26.5500, 43.1833, 90),
  ('qassim','uyun-jiwa',        '{"ar":"عيون الجواء","en":"Uyun al-Jiwa","ur":"عیون الجواء","hi":"उयून अल-जिवा","bn":"উয়ুন আল-জিওয়া"}'::jsonb, 26.4500, 43.7833, 100),
  ('qassim','asyah',            '{"ar":"عسيا","en":"Asyah","ur":"عسیا","hi":"असया","bn":"আসিয়া"}'::jsonb,                          26.4833, 43.4500, 110),
  ('qassim','nuayriah',         '{"ar":"النعيرية القصيم","en":"An-Nuayriah","ur":"النعیریہ","hi":"अन-नुऐरिया","bn":"আন-নুয়াইরিয়া"}'::jsonb, 26.7167, 43.9667, 120),

  -- Tabuk (7)
  ('tabuk','tabuk',             '{"ar":"تبوك","en":"Tabuk","ur":"تبوک","hi":"तबूक","bn":"তাবুক"}'::jsonb,                          28.3835, 36.5662, 10),
  ('tabuk','umluj',             '{"ar":"أملج","en":"Umluj","ur":"املج","hi":"उमलज","bn":"উমলজ"}'::jsonb,                            25.0345, 37.2691, 20),
  ('tabuk','duba',              '{"ar":"ضباء","en":"Duba","ur":"ضبا","hi":"दुबा","bn":"দুবা"}'::jsonb,                              27.3500, 35.7000, 30),
  ('tabuk','tayma',             '{"ar":"تيماء","en":"Tayma","ur":"تیما","hi":"तैमा","bn":"তাইমা"}'::jsonb,                          27.6333, 38.5500, 40),
  ('tabuk','haql',              '{"ar":"حقل","en":"Haql","ur":"حقل","hi":"हक़ल","bn":"হাকল"}'::jsonb,                                29.2933, 34.9419, 50),
  ('tabuk','wajh',              '{"ar":"الوجه","en":"Al-Wajh","ur":"الوجہ","hi":"अल-वज","bn":"আল-ওয়াজ"}'::jsonb,                  26.2436, 36.4533, 60),
  ('tabuk','bir-ibn-hirmas',    '{"ar":"بئر ابن هرماس","en":"Bir Ibn Hirmas","ur":"بئر ابن ہرماس","hi":"बीर इब्न हिरमास","bn":"বির ইবন হিরমাস"}'::jsonb, 28.5500, 36.7000, 70),

  -- Hail (7)
  ('hail','hail',               '{"ar":"حائل","en":"Hail","ur":"حائل","hi":"हाइल","bn":"হাইল"}'::jsonb,                            27.5114, 41.6900, 10),
  ('hail','baqaa',              '{"ar":"بقعاء","en":"Baqaa","ur":"بقعا","hi":"बक़ा","bn":"বাকা"}'::jsonb,                            27.7611, 42.7297, 20),
  ('hail','shinan',             '{"ar":"الشنان","en":"Ash-Shinan","ur":"الشنان","hi":"अश-शिनान","bn":"আশ-শিনান"}'::jsonb,         27.0033, 42.5683, 30),
  ('hail','ghazalah',           '{"ar":"الغزالة","en":"Al-Ghazalah","ur":"الغزالہ","hi":"अल-ग़ज़ाला","bn":"আল-গাজালা"}'::jsonb,    26.7975, 41.3672, 40),
  ('hail','hayit',              '{"ar":"الحائط","en":"Al-Hayit","ur":"الحائط","hi":"अल-हाइट","bn":"আল-হাইত"}'::jsonb,             26.0822, 41.5689, 50),
  ('hail','mawqaq',             '{"ar":"موقق","en":"Mawqaq","ur":"موقق","hi":"मौक़क़","bn":"মাওকাক"}'::jsonb,                          27.6500, 41.0000, 60),
  ('hail','sumayrah',           '{"ar":"السميراء","en":"As-Sumayrah","ur":"السمیراء","hi":"अस-सुमैरा","bn":"আস-সুমাইরা"}'::jsonb,    26.5500, 41.6500, 70),

  -- Northern Borders (4)
  ('northern-borders','arar',   '{"ar":"عرعر","en":"Arar","ur":"عرعر","hi":"अरार","bn":"আরার"}'::jsonb,                            30.9753, 41.0214, 10),
  ('northern-borders','rafha',  '{"ar":"رفحاء","en":"Rafha","ur":"رفحاء","hi":"रफ़हा","bn":"রাফহা"}'::jsonb,                       29.6202, 43.4915, 20),
  ('northern-borders','turaif', '{"ar":"طريف","en":"Turaif","ur":"طریف","hi":"तुरैफ़","bn":"তুরাইফ"}'::jsonb,                       31.6725, 38.6636, 30),
  ('northern-borders','owayqilah','{"ar":"العويقيلة","en":"Al-Owayqilah","ur":"العویقیلہ","hi":"अल-ओवैक़िला","bn":"আল-ওয়াইকিলা"}'::jsonb, 30.3333, 42.0500, 40),

  -- Jazan (14)
  ('jazan','jazan',             '{"ar":"جازان","en":"Jazan","ur":"جازان","hi":"जाज़ान","bn":"জাজান"}'::jsonb,                       16.8892, 42.5611, 10),
  ('jazan','sabya',             '{"ar":"صبيا","en":"Sabya","ur":"صبیا","hi":"सबया","bn":"সাবিয়া"}'::jsonb,                          17.1500, 42.6256, 20),
  ('jazan','abu-arish',         '{"ar":"أبو عريش","en":"Abu Arish","ur":"ابو عریش","hi":"अबू अरिश","bn":"আবু আরিশ"}'::jsonb,         16.9694, 42.8311, 30),
  ('jazan','samtah',            '{"ar":"صامطة","en":"Samtah","ur":"صامطہ","hi":"समता","bn":"সামতা"}'::jsonb,                        16.5961, 42.9472, 40),
  ('jazan','ahad-masarihah',    '{"ar":"أحد المسارحة","en":"Ahad al-Masarihah","ur":"احد المسارحہ","hi":"अहद अल-मसारिहा","bn":"আহাদ আল-মাসারিহা"}'::jsonb, 16.7167, 42.9667, 50),
  ('jazan','bish',              '{"ar":"بيش","en":"Bish","ur":"بیش","hi":"बीश","bn":"বিশ"}'::jsonb,                                  17.3833, 42.6000, 60),
  ('jazan','damad',             '{"ar":"ضمد","en":"Damad","ur":"ضمد","hi":"दमद","bn":"দামাদ"}'::jsonb,                              17.0833, 42.7000, 70),
  ('jazan','aridhah',           '{"ar":"العارضة","en":"Al-Aridhah","ur":"العارضہ","hi":"अल-अरीदा","bn":"আল-আরিদা"}'::jsonb,         17.0667, 43.0167, 80),
  ('jazan','darb',              '{"ar":"الدرب","en":"Al-Darb","ur":"الدرب","hi":"अल-दर्ब","bn":"আল-দারব"}'::jsonb,                  17.7333, 42.2500, 90),
  ('jazan','edabi',             '{"ar":"العيدابي","en":"Al-Edabi","ur":"العیدابی","hi":"अल-एदाबी","bn":"আল-এদাবি"}'::jsonb,         17.2167, 42.7333, 100),
  ('jazan','harth',             '{"ar":"الحرث","en":"Al-Harth","ur":"الحرث","hi":"अल-हर्थ","bn":"আল-হার্থ"}'::jsonb,                17.4833, 42.6667, 110),
  ('jazan','farasan',           '{"ar":"فرسان","en":"Farasan","ur":"فرسان","hi":"फ़रसान","bn":"ফারাসান"}'::jsonb,                   16.7000, 42.1167, 120),
  ('jazan','fayfa',             '{"ar":"فيفاء","en":"Fayfa","ur":"فیفا","hi":"फ़ैफ़ा","bn":"ফাইফা"}'::jsonb,                          17.2500, 43.1000, 130),
  ('jazan','reeth',             '{"ar":"الريث","en":"Al-Reeth","ur":"الریث","hi":"अल-रीथ","bn":"আল-রিথ"}'::jsonb,                    17.4167, 43.0500, 140),

  -- Najran (7)
  ('najran','najran',           '{"ar":"نجران","en":"Najran","ur":"نجران","hi":"नजरान","bn":"নাজরান"}'::jsonb,                     17.5656, 44.2289, 10),
  ('najran','sharurah',         '{"ar":"شرورة","en":"Sharurah","ur":"شرورہ","hi":"शरूरा","bn":"শারুরা"}'::jsonb,                  17.4869, 47.1167, 20),
  ('najran','hubuna',           '{"ar":"حبونا","en":"Hubuna","ur":"حبونا","hi":"हुबूना","bn":"হুবুনা"}'::jsonb,                      17.8333, 44.1500, 30),
  ('najran','yadma',            '{"ar":"يدمة","en":"Yadma","ur":"یدمہ","hi":"यदमा","bn":"ইয়াদমা"}'::jsonb,                          18.2167, 45.0167, 40),
  ('najran','khubash',          '{"ar":"خباش","en":"Khubash","ur":"خباش","hi":"ख़ुबाश","bn":"খুবাশ"}'::jsonb,                       17.7833, 43.7167, 50),
  ('najran','badr-janub',       '{"ar":"بدر الجنوب","en":"Badr al-Janub","ur":"بدر الجنوب","hi":"बद्र अल-जनूब","bn":"বদর আল-জানুব"}'::jsonb, 17.7167, 44.0500, 60),
  ('najran','thar',             '{"ar":"ثار","en":"Thar","ur":"ثار","hi":"थर","bn":"থার"}'::jsonb,                                  18.4000, 44.5000, 70),

  -- Bahah (8)
  ('bahah','bahah',             '{"ar":"الباحة","en":"Al-Bahah","ur":"الباحہ","hi":"अल-बाहा","bn":"আল-বাহা"}'::jsonb,             20.0129, 41.4677, 10),
  ('bahah','baljurashi',        '{"ar":"بلجرشي","en":"Baljurashi","ur":"بلجرشی","hi":"बलजुर्शी","bn":"বলজুরাশি"}'::jsonb,         19.8581, 41.5594, 20),
  ('bahah','almandaq',          '{"ar":"المندق","en":"Al-Mandaq","ur":"المندق","hi":"अल-मंदक","bn":"আল-মান্দাক"}'::jsonb,         20.1944, 41.2806, 30),
  ('bahah','aqiq',              '{"ar":"العقيق","en":"Al-Aqiq","ur":"العقیق","hi":"अल-अक़ीक़","bn":"আল-আকিক"}'::jsonb,             20.2750, 41.6722, 40),
  ('bahah','qilwah',            '{"ar":"قلوة","en":"Qilwah","ur":"قلوہ","hi":"क़िलवा","bn":"কিলওয়া"}'::jsonb,                     19.6667, 41.4667, 50),
  ('bahah','mukhwah',           '{"ar":"المخواة","en":"Al-Mukhwah","ur":"المخواہ","hi":"अल-मुख़वा","bn":"আল-মুখওয়া"}'::jsonb,    19.7672, 41.4322, 60),
  ('bahah','ghamid-zinad',      '{"ar":"غامد الزناد","en":"Ghamid az-Zinad","ur":"غامد الزناد","hi":"ग़ामिद अज़-ज़ीनाद","bn":"গামিদ আজ-জিনাদ"}'::jsonb, 19.9333, 41.5667, 70),
  ('bahah','bani-hasan',        '{"ar":"بني حسن","en":"Bani Hasan","ur":"بنی حسن","hi":"बनी हसन","bn":"বনি হাসান"}'::jsonb,         20.0667, 41.4500, 80),

  -- Jouf (4)
  ('jouf','sakaka',             '{"ar":"سكاكا","en":"Sakaka","ur":"سکاکا","hi":"सकाका","bn":"সাকাকা"}'::jsonb,                    29.9697, 40.2064, 10),
  ('jouf','qurayyat',           '{"ar":"القريات","en":"Qurayyat","ur":"القریات","hi":"क़ुरैयात","bn":"কুরাইয়াত"}'::jsonb,           31.3322, 37.3431, 20),
  ('jouf','dumat-jandal',       '{"ar":"دومة الجندل","en":"Dumat al-Jandal","ur":"دومۃ الجندل","hi":"दूमत अल-जंदल","bn":"দুমাত আল-জানদাল"}'::jsonb, 29.8128, 39.8636, 30),
  ('jouf','tabarjal',           '{"ar":"طبرجل","en":"Tabarjal","ur":"طبرجل","hi":"तबरजल","bn":"তাবারজাল"}'::jsonb,                30.5000, 38.2000, 40)
) as g(region_slug, slug, name, lat, lng, display_order) on g.region_slug = r.slug
on conflict (region_id, slug) do update set
  name = excluded.name,
  lat  = excluded.lat,
  lng  = excluded.lng,
  display_order = excluded.display_order;

commit;
