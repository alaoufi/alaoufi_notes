import { NextResponse } from "next/server";

/**
 * Public health probe — exposes only booleans about which env vars are
 * configured (never the values), so you can confirm Vercel propagated
 * the settings without revealing secrets.
 */

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

function present(name: string): boolean {
  const v = process.env[name];
  return Boolean(v && v.length > 0 && !v.startsWith("ey..."));
}

export function GET() {
  return NextResponse.json(
    {
      ok: true,
      timestamp: new Date().toISOString(),
      buildCommit: process.env.VERCEL_GIT_COMMIT_SHA ?? null,
      buildBranch: process.env.VERCEL_GIT_COMMIT_REF ?? null,
      env: {
        supabaseUrl: present("NEXT_PUBLIC_SUPABASE_URL"),
        supabaseAnonKey: present("NEXT_PUBLIC_SUPABASE_ANON_KEY"),
        supabaseServiceRoleKey: present("SUPABASE_SERVICE_ROLE_KEY"),
        googleMapsClientKey: present("NEXT_PUBLIC_GOOGLE_MAPS_API_KEY"),
        googleMapsServerKey: present("GOOGLE_MAPS_SERVER_KEY"),
        googleTranslateKey: present("GOOGLE_TRANSLATE_API_KEY"),
      },
      // True if the runtime sees the keys our app needs to talk to Supabase.
      hasSupabaseBackend:
        present("NEXT_PUBLIC_SUPABASE_URL") &&
        present("NEXT_PUBLIC_SUPABASE_ANON_KEY"),
    },
    {
      headers: {
        "Cache-Control": "no-store",
      },
    },
  );
}
