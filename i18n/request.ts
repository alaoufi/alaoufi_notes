import { getRequestConfig } from "next-intl/server";
import { notFound } from "next/navigation";
import { defaultLocale, locales, type Locale } from "./locales";
import {
  flattenMessages,
  unflattenMessages,
  mergeOverrides,
} from "@/lib/i18n/cms";
import { fetchTranslationOverrides } from "@/lib/i18n/cms-loader";

export default getRequestConfig(async ({ requestLocale }) => {
  const requested = await requestLocale;
  const locale = (locales.includes(requested as Locale) ? requested : defaultLocale) as Locale;

  let messages: Record<string, unknown>;
  try {
    messages = (await import(`../messages/${locale}.json`)).default;
  } catch {
    notFound();
  }

  // Merge in admin-edited overrides from the translations table. When the
  // table is empty or Supabase isn't configured this is a no-op, so the
  // shipped JSON file remains the source of truth.
  try {
    const overrides = await fetchTranslationOverrides(locale as Locale);
    if (Object.keys(overrides).length > 0) {
      const flat = flattenMessages(messages);
      const merged = mergeOverrides(flat, overrides);
      messages = unflattenMessages(merged);
    }
  } catch {
    // ignore — fall back to the shipped messages
  }

  return {
    locale,
    messages,
    timeZone: "Asia/Riyadh",
    now: new Date(),
  };
});
