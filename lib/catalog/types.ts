import type { Locale } from "@/i18n/locales";

export interface Category {
  id?: string;
  slug: string;
  name: Record<string, string>;
  icon_key: string | null;
}

export interface City {
  id?: string;
  slug: string;
  name: Record<string, string>;
}

export function localized(field: Record<string, string> | null | undefined, locale: Locale): string {
  if (!field) return "";
  return field[locale] ?? field.ar ?? field.en ?? Object.values(field)[0] ?? "";
}
