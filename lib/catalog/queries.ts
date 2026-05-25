import "server-only";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import type { Category, City, Region, Governorate } from "./types";

export type { Category, City, Region, Governorate, District } from "./types";
export { localized } from "./types";

const FALLBACK_CATEGORIES: Category[] = [
  { slug: "hvac",       name: { ar: "تكييف وتبريد", en: "HVAC", ur: "اے سی", hi: "एसी", bn: "এসি" },           icon_key: "Wind" },
  { slug: "plumbing",   name: { ar: "سباكة",        en: "Plumbing", ur: "پلمبنگ", hi: "प्लंबिंग", bn: "প্লাম্বিং" }, icon_key: "Wrench" },
  { slug: "electrical", name: { ar: "كهرباء",       en: "Electrical", ur: "بجلی", hi: "बिजली", bn: "বৈদ্যুতিক" },   icon_key: "Zap" },
  { slug: "appliances", name: { ar: "أجهزة منزلية", en: "Appliances", ur: "گھریلو آلات", hi: "घरेलू उपकरण", bn: "গৃহস্থালী" }, icon_key: "WashingMachine" },
  { slug: "home",       name: { ar: "صيانة عامة",   en: "General",    ur: "عمومی", hi: "सामान्य", bn: "সাধারণ" },           icon_key: "Home" },
  { slug: "vehicle",    name: { ar: "صيانة سيارات", en: "Vehicle",    ur: "گاڑی", hi: "वाहन", bn: "গাড়ি" },              icon_key: "Car" },
  { slug: "cleaning",   name: { ar: "نظافة",        en: "Cleaning",   ur: "صفائی", hi: "सफ़ाई", bn: "পরিষ্কার" },          icon_key: "Sparkles" },
  { slug: "pest",       name: { ar: "مكافحة حشرات", en: "Pest",      ur: "کیڑے", hi: "कीट", bn: "কীট" },             icon_key: "Bug" },
];

// All 13 Saudi regions — mirrors the seed in migration 0016.
// Default activation pattern in the fallback: four major regions on, others off,
// so the public site already shows realistic governorates even before Supabase
// is wired and an admin has flipped the toggles.
const FALLBACK_REGIONS: Region[] = [
  { slug: "riyadh",           name: { ar: "منطقة الرياض",            en: "Riyadh Region" },     is_active: true,  display_order: 10  },
  { slug: "makkah",           name: { ar: "منطقة مكة المكرمة",       en: "Makkah Region" },     is_active: true,  display_order: 20  },
  { slug: "madinah",          name: { ar: "منطقة المدينة المنورة",   en: "Madinah Region" },    is_active: true,  display_order: 30  },
  { slug: "eastern",          name: { ar: "المنطقة الشرقية",          en: "Eastern Province" },  is_active: true,  display_order: 40  },
  { slug: "asir",             name: { ar: "منطقة عسير",              en: "Asir Region" },       is_active: false, display_order: 50  },
  { slug: "qassim",           name: { ar: "منطقة القصيم",            en: "Qassim Region" },     is_active: false, display_order: 60  },
  { slug: "tabuk",            name: { ar: "منطقة تبوك",              en: "Tabuk Region" },      is_active: false, display_order: 70  },
  { slug: "hail",             name: { ar: "منطقة حائل",              en: "Hail Region" },       is_active: false, display_order: 80  },
  { slug: "northern-borders", name: { ar: "منطقة الحدود الشمالية",   en: "Northern Borders" },  is_active: false, display_order: 90  },
  { slug: "jazan",            name: { ar: "منطقة جازان",             en: "Jazan Region" },      is_active: false, display_order: 100 },
  { slug: "najran",           name: { ar: "منطقة نجران",             en: "Najran Region" },     is_active: false, display_order: 110 },
  { slug: "bahah",            name: { ar: "منطقة الباحة",            en: "Al-Bahah Region" },   is_active: false, display_order: 120 },
  { slug: "jouf",             name: { ar: "منطقة الجوف",             en: "Al-Jawf Region" },    is_active: false, display_order: 130 },
];

const FALLBACK_GOVERNORATES: Governorate[] = [
  // Riyadh — active
  { region_slug: "riyadh", slug: "riyadh",        name: { ar: "الرياض",       en: "Riyadh" },         is_active: true,  display_order: 10 },
  { region_slug: "riyadh", slug: "diriyah",       name: { ar: "الدرعية",      en: "Diriyah" },        is_active: true,  display_order: 20 },
  { region_slug: "riyadh", slug: "kharj",         name: { ar: "الخرج",        en: "Al-Kharj" },       is_active: true,  display_order: 30 },
  { region_slug: "riyadh", slug: "dawadmi",       name: { ar: "الدوادمي",     en: "Dawadmi" },        is_active: true,  display_order: 40 },
  { region_slug: "riyadh", slug: "majmaah",       name: { ar: "المجمعة",      en: "Al-Majmaah" },     is_active: true,  display_order: 50 },
  // Makkah — active
  { region_slug: "makkah", slug: "makkah",        name: { ar: "مكة المكرمة",  en: "Makkah" },         is_active: true,  display_order: 10 },
  { region_slug: "makkah", slug: "jeddah",        name: { ar: "جدة",          en: "Jeddah" },         is_active: true,  display_order: 20 },
  { region_slug: "makkah", slug: "taif",          name: { ar: "الطائف",       en: "Taif" },           is_active: true,  display_order: 30 },
  { region_slug: "makkah", slug: "qunfudhah",     name: { ar: "القنفذة",      en: "Al-Qunfudhah" },   is_active: true,  display_order: 40 },
  { region_slug: "makkah", slug: "rabigh",        name: { ar: "رابغ",         en: "Rabigh" },         is_active: true,  display_order: 50 },
  // Madinah — active
  { region_slug: "madinah", slug: "madinah",      name: { ar: "المدينة المنورة", en: "Madinah" },     is_active: true,  display_order: 10 },
  { region_slug: "madinah", slug: "yanbu",        name: { ar: "ينبع",         en: "Yanbu" },          is_active: true,  display_order: 20 },
  { region_slug: "madinah", slug: "ula",          name: { ar: "العلا",        en: "Al-Ula" },         is_active: true,  display_order: 30 },
  // Eastern — active
  { region_slug: "eastern", slug: "dammam",       name: { ar: "الدمام",       en: "Dammam" },         is_active: true,  display_order: 10 },
  { region_slug: "eastern", slug: "ahsa",         name: { ar: "الأحساء",      en: "Al-Ahsa" },        is_active: true,  display_order: 20 },
  { region_slug: "eastern", slug: "khobar",       name: { ar: "الخبر",        en: "Khobar" },         is_active: true,  display_order: 30 },
  { region_slug: "eastern", slug: "dhahran",      name: { ar: "الظهران",      en: "Dhahran" },        is_active: true,  display_order: 40 },
  { region_slug: "eastern", slug: "jubail",       name: { ar: "الجبيل",       en: "Jubail" },         is_active: true,  display_order: 50 },
  { region_slug: "eastern", slug: "qatif",        name: { ar: "القطيف",       en: "Qatif" },          is_active: true,  display_order: 60 },
  // Asir — inactive
  { region_slug: "asir",   slug: "abha",           name: { ar: "أبها",         en: "Abha" },           is_active: false, display_order: 10 },
  { region_slug: "asir",   slug: "khamis-mushait", name: { ar: "خميس مشيط",    en: "Khamis Mushait" }, is_active: false, display_order: 20 },
  // Qassim — inactive
  { region_slug: "qassim", slug: "buraidah",      name: { ar: "بريدة",        en: "Buraidah" },       is_active: false, display_order: 10 },
  { region_slug: "qassim", slug: "unaizah",       name: { ar: "عنيزة",        en: "Unaizah" },        is_active: false, display_order: 20 },
  // Others (each region's main governorate, all inactive)
  { region_slug: "tabuk",  slug: "tabuk",         name: { ar: "تبوك",         en: "Tabuk" },          is_active: false, display_order: 10 },
  { region_slug: "hail",   slug: "hail",          name: { ar: "حائل",         en: "Hail" },           is_active: false, display_order: 10 },
  { region_slug: "northern-borders", slug: "arar",name: { ar: "عرعر",         en: "Arar" },           is_active: false, display_order: 10 },
  { region_slug: "jazan",  slug: "jazan",         name: { ar: "جازان",        en: "Jazan" },          is_active: false, display_order: 10 },
  { region_slug: "najran", slug: "najran",        name: { ar: "نجران",        en: "Najran" },         is_active: false, display_order: 10 },
  { region_slug: "bahah",  slug: "bahah",         name: { ar: "الباحة",       en: "Al-Bahah" },       is_active: false, display_order: 10 },
  { region_slug: "jouf",   slug: "sakaka",        name: { ar: "سكاكا",        en: "Sakaka" },         is_active: false, display_order: 10 },
];

// Cities visible to the public = governorates whose parent region is active and
// the governorate itself is active.
const FALLBACK_CITIES: City[] = FALLBACK_GOVERNORATES.filter((g) => {
  const region = FALLBACK_REGIONS.find((r) => r.slug === g.region_slug);
  return Boolean(region?.is_active) && g.is_active;
}).map((g) => ({
  slug: g.slug,
  name: g.name,
  governorate_slug: g.slug,
  region_slug: g.region_slug,
  is_active: true,
}));

export async function listCategories(): Promise<Category[]> {
  if (!hasSupabaseEnv()) return FALLBACK_CATEGORIES;
  try {
    const supabase = await createSupabaseServerClient();
    const { data, error } = await supabase
      .from("categories" as never)
      .select("id, slug, name, icon_key")
      .eq("is_active", true)
      .order("display_order");
    if (error || !data) return FALLBACK_CATEGORIES;
    return data as unknown as Category[];
  } catch {
    return FALLBACK_CATEGORIES;
  }
}

export async function findCategoryBySlug(slug: string): Promise<Category | null> {
  const all = await listCategories();
  return all.find((c) => c.slug === slug) ?? null;
}

export async function listCities(): Promise<City[]> {
  if (!hasSupabaseEnv()) return FALLBACK_CITIES;
  try {
    const supabase = await createSupabaseServerClient();
    const { data, error } = await supabase
      .from("cities_visible" as never)
      .select("id, slug, name, governorate_id")
      .order("display_order");
    if (error || !data) return FALLBACK_CITIES;
    return data as unknown as City[];
  } catch {
    return FALLBACK_CITIES;
  }
}

/** All regions including inactive — for admin views. */
export async function listAllRegions(): Promise<Region[]> {
  if (!hasSupabaseEnv()) return FALLBACK_REGIONS;
  try {
    const supabase = await createSupabaseServerClient();
    const { data, error } = await supabase
      .from("regions" as never)
      .select("id, slug, name, is_active, display_order")
      .order("display_order");
    if (error || !data) return FALLBACK_REGIONS;
    return data as unknown as Region[];
  } catch {
    return FALLBACK_REGIONS;
  }
}

/** Active regions only — for the public site. */
export async function listActiveRegions(): Promise<Region[]> {
  const all = await listAllRegions();
  return all.filter((r) => r.is_active);
}

/** Governorates of a region. Includes inactive (RLS filters for non-admins). */
export async function listGovernorates(regionSlug: string): Promise<Governorate[]> {
  if (!hasSupabaseEnv()) {
    return FALLBACK_GOVERNORATES.filter((g) => g.region_slug === regionSlug);
  }
  try {
    const supabase = await createSupabaseServerClient();
    const { data: region, error: regErr } = await supabase
      .from("regions" as never)
      .select("id")
      .eq("slug", regionSlug)
      .maybeSingle();
    if (regErr || !region) return [];
    const regionId = (region as { id: string }).id;
    const { data, error } = await supabase
      .from("governorates" as never)
      .select("id, region_id, slug, name, is_active, display_order")
      .eq("region_id", regionId)
      .order("display_order");
    if (error || !data) return [];
    return data as unknown as Governorate[];
  } catch {
    return FALLBACK_GOVERNORATES.filter((g) => g.region_slug === regionSlug);
  }
}
