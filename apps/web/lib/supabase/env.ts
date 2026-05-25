function read(name: string): string | undefined {
  const v = process.env[name];
  return v && v.length > 0 ? v : undefined;
}

function required(name: string): string {
  const v = read(name);
  if (!v) {
    throw new Error(
      `[supabase] Missing required env var ${name}. ` +
        `Copy .env.example to apps/web/.env.local and fill it in.`,
    );
  }
  return v;
}

// Lazy getters so build-time (which has no env) doesn't fail; only runtime usage triggers errors.
export const supabaseEnv = {
  get url() {
    return required("NEXT_PUBLIC_SUPABASE_URL");
  },
  get anonKey() {
    return required("NEXT_PUBLIC_SUPABASE_ANON_KEY");
  },
};

export function getServiceRoleKey(): string {
  return required("SUPABASE_SERVICE_ROLE_KEY");
}

export function hasSupabaseEnv(): boolean {
  return !!read("NEXT_PUBLIC_SUPABASE_URL") && !!read("NEXT_PUBLIC_SUPABASE_ANON_KEY");
}
