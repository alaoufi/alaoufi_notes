import "server-only";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import type { Category, City } from "./types";

export type { Category, City } from "./types";
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

const FALLBACK_CITIES: City[] = [
  { slug: "riyadh",   name: { ar: "الرياض", en: "Riyadh" } },
  { slug: "jeddah",   name: { ar: "جدّة", en: "Jeddah" } },
  { slug: "makkah",   name: { ar: "مكة المكرّمة", en: "Makkah" } },
  { slug: "madinah",  name: { ar: "المدينة المنورة", en: "Madinah" } },
  { slug: "dammam",   name: { ar: "الدمام", en: "Dammam" } },
  { slug: "khobar",   name: { ar: "الخبر", en: "Khobar" } },
  { slug: "dhahran",  name: { ar: "الظهران", en: "Dhahran" } },
  { slug: "taif",     name: { ar: "الطائف", en: "Taif" } },
  { slug: "tabuk",    name: { ar: "تبوك", en: "Tabuk" } },
  { slug: "abha",     name: { ar: "أبها", en: "Abha" } },
  { slug: "khamis",   name: { ar: "خميس مشيط", en: "Khamis Mushait" } },
  { slug: "hail",     name: { ar: "حائل", en: "Hail" } },
  { slug: "buraidah", name: { ar: "بريدة", en: "Buraidah" } },
  { slug: "najran",   name: { ar: "نجران", en: "Najran" } },
];

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

export async function listCities(): Promise<City[]> {
  if (!hasSupabaseEnv()) return FALLBACK_CITIES;
  try {
    const supabase = await createSupabaseServerClient();
    const { data, error } = await supabase
      .from("cities" as never)
      .select("id, slug, name")
      .eq("is_active", true)
      .order("display_order");
    if (error || !data) return FALLBACK_CITIES;
    return data as unknown as City[];
  } catch {
    return FALLBACK_CITIES;
  }
}

export async function findCategoryBySlug(slug: string): Promise<Category | null> {
  const all = await listCategories();
  return all.find((c) => c.slug === slug) ?? null;
}
