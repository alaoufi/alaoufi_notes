import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { supabaseEnv, getServiceRoleKey } from "./env";
import type { Database } from "./types";

export async function createSupabaseServerClient() {
  const cookieStore = await cookies();
  return createServerClient<Database>(supabaseEnv.url, supabaseEnv.anonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(toSet) {
        try {
          for (const { name, value, options } of toSet) {
            cookieStore.set(name, value, options);
          }
        } catch {
          // setAll fails inside Server Components — safe to ignore; middleware sets cookies first.
        }
      },
    },
  });
}

// Service-role client — bypasses RLS. NEVER expose to the browser.
// Use exclusively inside server actions / route handlers that already enforce permission themselves.
export function createSupabaseServiceRoleClient() {
  return createServerClient<Database>(supabaseEnv.url, getServiceRoleKey(), {
    cookies: {
      getAll() {
        return [];
      },
      setAll() {
        // no-op
      },
    },
  });
}
