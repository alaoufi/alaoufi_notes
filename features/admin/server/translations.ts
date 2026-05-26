"use server";

import { revalidatePath } from "next/cache";
import { createSupabaseServiceRoleClient } from "@/lib/supabase/server";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import { requireAdminSection } from "@/lib/auth/sections";
import { locales, type Locale } from "@/i18n/locales";

export interface SaveTranslationInput {
  key: string;
  locale: Locale;
  value: string;
}

export interface SaveResult {
  ok: boolean;
  errorKey?: string;
  saved?: number;
}

export async function saveTranslations(
  updates: SaveTranslationInput[],
): Promise<SaveResult> {
  if (!hasSupabaseEnv()) {
    return { ok: false, errorKey: "admin.translations.errors.noBackend" };
  }
  await requireAdminSection("translations");

  if (!Array.isArray(updates) || updates.length === 0) {
    return { ok: true, saved: 0 };
  }

  // Validate inputs.
  const clean = updates.filter(
    (u) =>
      typeof u.key === "string" &&
      u.key.length > 0 &&
      u.key.length < 200 &&
      locales.includes(u.locale) &&
      typeof u.value === "string" &&
      u.value.length < 4000,
  );

  const admin = createSupabaseServiceRoleClient();

  // Split into upserts (non-empty) and deletes (empty value means "revert to
  // the shipped JSON default").
  const upserts = clean.filter((u) => u.value.trim().length > 0);
  const deletes = clean.filter((u) => u.value.trim().length === 0);

  if (upserts.length > 0) {
    const { error } = await admin
      .from("translations" as never)
      .upsert(
        upserts.map((u) => ({
          key: u.key,
          locale: u.locale,
          value: u.value,
        })) as never,
        { onConflict: "key,locale" },
      );
    if (error) {
      return { ok: false, errorKey: "admin.translations.errors.saveFailed" };
    }
  }

  for (const u of deletes) {
    await admin
      .from("translations" as never)
      .delete()
      .eq("key", u.key)
      .eq("locale", u.locale);
  }

  // Bust every locale page so updated strings are visible immediately.
  for (const loc of locales) {
    revalidatePath(`/${loc}`, "layout");
  }

  return { ok: true, saved: clean.length };
}
