import type { Locale } from "@/i18n/locales";

export interface Category {
  id?: string;
  slug: string;
  name: Record<string, string>;
  icon_key: string | null;
}

export interface Region {
  id?: string;
  slug: string;
  name: Record<string, string>;
  is_active: boolean;
  display_order?: number;
}

export interface Governorate {
  id?: string;
  region_id?: string;
  region_slug?: string;
  slug: string;
  name: Record<string, string>;
  is_active: boolean;
  display_order?: number;
}

export interface City {
  id?: string;
  governorate_id?: string;
  governorate_slug?: string;
  region_slug?: string;
  slug: string;
  name: Record<string, string>;
  is_active?: boolean;
}

export interface District {
  id?: string;
  city_id?: string;
  city_slug?: string;
  slug: string;
  name: Record<string, string>;
  lat?: number | null;
  lng?: number | null;
}

export function localized(field: Record<string, string> | null | undefined, locale: Locale): string {
  if (!field) return "";
  return field[locale] ?? field.ar ?? field.en ?? Object.values(field)[0] ?? "";
}
