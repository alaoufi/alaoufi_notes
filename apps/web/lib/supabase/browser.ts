import { createBrowserClient } from "@supabase/ssr";
import { supabaseEnv } from "./env";
import type { Database } from "./types";

export function createSupabaseBrowserClient() {
  return createBrowserClient<Database>(supabaseEnv.url, supabaseEnv.anonKey);
}
