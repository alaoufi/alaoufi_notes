import { describe, it, expect } from "vitest";
import { locales } from "@/i18n/locales";
import ar from "@/messages/ar.json";
import ur from "@/messages/ur.json";
import en from "@/messages/en.json";
import hi from "@/messages/hi.json";
import bn from "@/messages/bn.json";

const all: Record<string, Record<string, unknown>> = { ar, ur, en, hi, bn };

function flatten(obj: unknown, prefix = ""): string[] {
  if (typeof obj !== "object" || obj == null) return [prefix];
  const keys: string[] = [];
  for (const [k, v] of Object.entries(obj)) {
    const next = prefix ? `${prefix}.${k}` : k;
    keys.push(...flatten(v, next));
  }
  return keys;
}

describe("translation files", () => {
  it("ship a file for every locale", () => {
    for (const loc of locales) {
      expect(all[loc]).toBeDefined();
    }
  });

  it("every locale has the same set of keys as ar (no missing translations)", () => {
    const arKeys = new Set(flatten(ar));
    for (const loc of locales) {
      const locKeys = new Set(flatten(all[loc]));
      const missing = [...arKeys].filter((k) => !locKeys.has(k));
      const extra = [...locKeys].filter((k) => !arKeys.has(k));
      if (missing.length || extra.length) {
        // help debugging
        // eslint-disable-next-line no-console
        console.warn(`[${loc}] missing=${missing.length} extra=${extra.length}`);
      }
      expect(missing, `missing keys in ${loc}`).toEqual([]);
      expect(extra, `extra keys in ${loc}`).toEqual([]);
    }
  });
});
