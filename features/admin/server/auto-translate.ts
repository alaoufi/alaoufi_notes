"use server";

import { requireAdminSection } from "@/lib/auth/sections";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import { locales, type Locale } from "@/i18n/locales";

const TARGET_LOCALES: Locale[] = ["en", "ur", "hi", "bn"];

interface TranslateRow {
  key: string;
  arabic: string;
}

export interface TranslateResult {
  ok: boolean;
  errorKey?: string;
  translations?: Record<string, Record<Locale, string>>;
  /** Locales we successfully covered. */
  covered?: Locale[];
}

function getKey(): string | null {
  const k = process.env.GOOGLE_TRANSLATE_API_KEY;
  return k && k.length > 0 ? k : null;
}

/**
 * Translates a batch of Arabic strings into the four target locales using
 * Google Cloud Translation v2. Requires the GOOGLE_TRANSLATE_API_KEY env var.
 *
 * Falls back gracefully — if the key isn't configured we return `ok: false`
 * with `errorKey` so the UI can show "configure the key to enable auto
 * translation" instead of failing silently.
 */
export async function autoTranslateAction(
  rows: TranslateRow[],
): Promise<TranslateResult> {
  if (!hasSupabaseEnv()) {
    return { ok: false, errorKey: "admin.translations.errors.noBackend" };
  }
  await requireAdminSection("translations");

  const apiKey = getKey();
  if (!apiKey) {
    return { ok: false, errorKey: "admin.translations.errors.noTranslateKey" };
  }

  const clean = rows.filter(
    (r) => r.arabic.trim().length > 0 && r.key.trim().length > 0,
  );
  if (clean.length === 0) return { ok: true, translations: {}, covered: [] };

  // Google Cloud Translation accepts up to 128 'q' params per request, with
  // a total payload cap; chunk to be safe.
  const chunks: TranslateRow[][] = [];
  for (let i = 0; i < clean.length; i += 50) {
    chunks.push(clean.slice(i, i + 50));
  }

  const translations: Record<string, Record<Locale, string>> = {};
  for (const row of clean) {
    translations[row.key] = { ar: row.arabic, en: "", ur: "", hi: "", bn: "" };
  }

  const covered: Locale[] = [];

  for (const target of TARGET_LOCALES) {
    let allOk = true;
    for (const chunk of chunks) {
      const params = new URLSearchParams();
      for (const row of chunk) params.append("q", row.arabic);
      params.append("source", "ar");
      params.append("target", target);
      params.append("format", "text");
      params.append("key", apiKey);

      try {
        const res = await fetch(
          "https://translation.googleapis.com/language/translate/v2?" +
            params.toString(),
          { method: "POST" },
        );
        if (!res.ok) {
          allOk = false;
          break;
        }
        type ApiResp = {
          data?: { translations?: Array<{ translatedText?: string }> };
        };
        const json = (await res.json()) as ApiResp;
        const out = json?.data?.translations ?? [];
        chunk.forEach((row, i) => {
          const value = out[i]?.translatedText ?? "";
          if (translations[row.key]) {
            translations[row.key]![target] = value;
          }
        });
      } catch {
        allOk = false;
        break;
      }
    }
    if (allOk) covered.push(target);
  }

  if (covered.length === 0) {
    return {
      ok: false,
      errorKey: "admin.translations.errors.translateFailed",
      translations,
    };
  }

  return { ok: true, translations, covered };
}

export async function isAutoTranslateAvailable(): Promise<boolean> {
  return getKey() !== null;
}

void locales;
