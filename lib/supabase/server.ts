import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { supabaseEnv } from "./env";
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

// The service-role client lives in `./service-role.ts` (no next/headers import)
// so it can be used from Edge Middleware / CMS loaders. Re-exported here so
// existing server-side importers keep working unchanged.
export { createSupabaseServiceRoleClient } from "./service-role";
