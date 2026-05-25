"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import { signUpSchema, type SignUpInput } from "../schema";
import { AuthError } from "@/lib/auth/errors";

export interface SignUpResult {
  ok: boolean;
  errorKey?: string;
  fieldErrors?: Record<string, string>;
}

export async function signUpAction(input: SignUpInput): Promise<SignUpResult> {
  const parsed = signUpSchema.safeParse(input);
  if (!parsed.success) {
    const fieldErrors: Record<string, string> = {};
    for (const issue of parsed.error.issues) {
      const key = issue.path[0]?.toString();
      if (key && !fieldErrors[key]) fieldErrors[key] = issue.message;
    }
    return { ok: false, errorKey: "auth.errors.invalidInput", fieldErrors };
  }

  if (!hasSupabaseEnv()) {
    // Demo / preview: pretend it worked so the user can see the rest of the flow.
    return { ok: true };
  }

  const {
    email,
    password,
    fullName,
    phone,
    role,
    locale,
    regionSlug,
    governorateSlug,
    citySlug,
    districtName,
    street,
    building,
    lat,
    lng,
  } = parsed.data;

  const supabase = await createSupabaseServerClient();

  const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: { full_name: fullName, phone_e164: phone, role, locale },
    },
  });

  if (signUpError) {
    if (signUpError.message?.toLowerCase().includes("registered")) {
      throw new AuthError("USER_EXISTS", "auth.errors.userExists", signUpError);
    }
    throw new AuthError("UNKNOWN", "auth.errors.unknown", signUpError);
  }

  const userId = signUpData.user?.id;
  if (!userId) {
    // Email confirmation pending — address saved later from profile page.
    return { ok: true };
  }

  // Best-effort: resolve slugs → ids and store the first address.
  try {
    const [regionRes, govRes, cityRes] = await Promise.all([
      supabase.from("regions" as never).select("id").eq("slug", regionSlug).maybeSingle(),
      supabase.from("governorates" as never).select("id").eq("slug", governorateSlug).maybeSingle(),
      supabase.from("cities" as never).select("id").eq("slug", citySlug).maybeSingle(),
    ]);

    type IdRow = { id: string } | null;
    const region_id = (regionRes.data as IdRow)?.id ?? null;
    const governorate_id = (govRes.data as IdRow)?.id ?? null;
    const city_id = (cityRes.data as IdRow)?.id ?? null;

    const location =
      typeof lat === "number" && typeof lng === "number" ? `POINT(${lng} ${lat})` : null;

    await supabase.from("user_addresses" as never).insert({
      user_id: userId,
      label: "home",
      region_id,
      governorate_id,
      city_id,
      district_name: districtName || null,
      street: street || null,
      building: building || null,
      location,
      is_default: true,
    } as never);
  } catch {
    // Non-fatal — user can fill the address from /profile later.
  }

  return { ok: true };
}
