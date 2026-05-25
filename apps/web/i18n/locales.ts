export const locales = ["ar", "ur", "en", "hi", "bn"] as const;
export type Locale = (typeof locales)[number];

export const defaultLocale: Locale = "ar";

export const localeNames: Record<Locale, string> = {
  ar: "العربية",
  ur: "اردو",
  en: "English",
  hi: "हिन्दी",
  bn: "বাংলা",
};

export const rtlLocales: Locale[] = ["ar", "ur"];

export function getDirection(locale: Locale): "rtl" | "ltr" {
  return rtlLocales.includes(locale) ? "rtl" : "ltr";
}
