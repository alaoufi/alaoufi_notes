/**
 * CMS helpers for runtime translation editing.
 *
 * Translations live in two layers:
 *   1. The JSON files under /messages — shipped with the build, deterministic.
 *   2. The `translations` table in Supabase — admin overrides, hot-editable.
 *
 * For any request we flatten the JSON, merge any overrides for that locale,
 * then un-flatten back into the nested shape next-intl expects.
 */

export type FlatMessages = Record<string, string>;

type MaybeMessages = Record<string, unknown> | string | number | boolean | null;

export function flattenMessages(
  obj: MaybeMessages,
  prefix = "",
): FlatMessages {
  const out: FlatMessages = {};
  if (obj == null) return out;
  if (typeof obj !== "object") {
    if (prefix) out[prefix] = String(obj);
    return out;
  }
  for (const [k, v] of Object.entries(obj)) {
    const next = prefix ? `${prefix}.${k}` : k;
    if (v != null && typeof v === "object" && !Array.isArray(v)) {
      Object.assign(out, flattenMessages(v as MaybeMessages, next));
    } else if (v != null) {
      out[next] = String(v);
    }
  }
  return out;
}

export function unflattenMessages(flat: FlatMessages): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(flat)) {
    const parts = key.split(".");
    let current: Record<string, unknown> = result;
    for (let i = 0; i < parts.length - 1; i++) {
      const k = parts[i]!;
      if (
        typeof current[k] !== "object" ||
        current[k] === null ||
        Array.isArray(current[k])
      ) {
        current[k] = {};
      }
      current = current[k] as Record<string, unknown>;
    }
    current[parts[parts.length - 1]!] = value;
  }
  return result;
}

export function mergeOverrides(
  base: FlatMessages,
  overrides: FlatMessages,
): FlatMessages {
  return { ...base, ...overrides };
}
