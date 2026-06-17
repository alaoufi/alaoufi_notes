import { createServerClient } from "@supabase/ssr";
import { supabaseEnv, getServiceRoleKey } from "./env";
import type { Database } from "./types";

// Service-role client — bypasses RLS. NEVER expose to the browser.
// Use exclusively inside server actions / route handlers that already enforce
// permission themselves.
//
// Lives in its own module (no `next/headers` import) so it can be used from
// Edge Middleware and the i18n CMS loader without leaking the cookies API into
// those bundles.
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
