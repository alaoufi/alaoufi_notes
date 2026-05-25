import "server-only";
import { createSupabaseServiceRoleClient } from "@/lib/supabase/server";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import type { Locale } from "@/i18n/locales";
import type { FlatMessages } from "./cms";

/**
 * Read all admin-edited overrides for one locale. Uses service-role so the
 * read works even on the public site (anon visitors) and stays cheap thanks
 * to a tight (key, locale) composite.
 *
 * Returns an empty object when Supabase is not configured or when the table
 * doesn't exist yet (e.g. migrations 0015+ not applied).
 */
export async function fetchTranslationOverrides(
  locale: Locale,
): Promise<FlatMessages> {
  if (!hasSupabaseEnv()) return {};
  try {
    const admin = createSupabaseServiceRoleClient();
    const { data, error } = await admin
      .from("translations" as never)
      .select("key, value")
      .eq("locale", locale);
    if (error || !data) return {};
    const out: FlatMessages = {};
    for (const row of data as Array<{ key: string; value: string }>) {
      out[row.key] = row.value;
    }
    return out;
  } catch {
    return {};
  }
}

/**
 * Read EVERY translation override across every locale — used by the admin
 * editor to seed the table view.
 */
export async function fetchAllOverrides(): Promise<
  Record<Locale, FlatMessages>
> {
  const empty: Record<Locale, FlatMessages> = {
    ar: {},
    ur: {},
    en: {},
    hi: {},
    bn: {},
  };
  if (!hasSupabaseEnv()) return empty;
  try {
    const admin = createSupabaseServiceRoleClient();
    const { data, error } = await admin
      .from("translations" as never)
      .select("key, locale, value");
    if (error || !data) return empty;
    for (const row of data as Array<{ key: string; locale: Locale; value: string }>) {
      if (empty[row.locale]) empty[row.locale][row.key] = row.value;
    }
    return empty;
  } catch {
    return empty;
  }
}
