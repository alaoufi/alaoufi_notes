// Client-safe admin section constants & types.
//
// Kept free of any server-only imports (no next/headers, no Supabase server
// client) so it can be imported from Client Components without pulling the
// cookies API into the browser bundle. Server-side helpers live in
// `./sections.ts`, which re-exports these for backward compatibility.

export const ADMIN_SECTIONS = [
  "categories",
  "geography",
  "users",
  "disputes",
  "translations",
  "settings",
  "orders",
  "payments",
  "ads",
] as const;

export type AdminSection = (typeof ADMIN_SECTIONS)[number];

export function isAdminSection(value: unknown): value is AdminSection {
  return typeof value === "string" && (ADMIN_SECTIONS as readonly string[]).includes(value);
}
