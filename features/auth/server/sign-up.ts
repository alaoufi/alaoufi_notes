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

/**
 * Phone is the required handle. If no email is provided we synthesize one
 * so Supabase Auth still has the identifier it needs, while the user always
 * signs in by phone or username.
 */
function synthesizeEmail(phoneE164: string): string {
  const digits = phoneE164.replace(/\D/g, "");
  return `${digits}@phone.syanah.app`;
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
    return { ok: true };
  }

  const {
    email,
    password,
    fullName,
    phone,
    username,
    roles,
    activeRole,
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

  const trimmedUsername = username?.trim() || null;
  const trimmedEmail = email?.trim() || null;
  const authEmail = trimmedEmail || synthesizeEmail(phone);

  const supabase = await createSupabaseServerClient();

  // Reject duplicate username early — gives a better error than the auth call.
  if (trimmedUsername) {
    const { data: existing } = await supabase
      .from("profiles" as never)
      .select("user_id")
      .eq("username", trimmedUsername)
      .maybeSingle();
    if (existing) {
      return {
        ok: false,
        errorKey: "auth.errors.usernameTaken",
        fieldErrors: { username: "auth.errors.usernameTaken" },
      };
    }
  }

  const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
    email: authEmail,
    password,
    options: {
      data: {
        full_name: fullName,
        phone_e164: phone,
        username: trimmedUsername,
        roles,
        active_role: activeRole,
        locale,
      },
    },
  });

  if (signUpError) {
    if (signUpError.message?.toLowerCase().includes("registered")) {
      throw new AuthError("USER_EXISTS", "auth.errors.userExists", signUpError);
    }
    throw new AuthError("UNKNOWN", "auth.errors.unknown", signUpError);
  }

  const userId = signUpData.user?.id;
  if (!userId) return { ok: true };

  // Patch profile with username + email override + active role.
  try {
    await supabase
      .from("profiles" as never)
      .update({
        username: trimmedUsername,
        email_normalized: trimmedEmail ? trimmedEmail.toLowerCase() : null,
        active_role: activeRole,
      } as never)
      .eq("user_id", userId);
  } catch {
    // non-fatal — handle_new_user trigger already created the row
  }

  // Make sure user_roles has every requested role.
  try {
    for (const role of roles) {
      await supabase
        .from("user_roles" as never)
        .upsert({ user_id: userId, role } as never, { onConflict: "user_id,role" });
    }
  } catch {
    // ignore — DB trigger handles a default role already
  }

  // Save the home address.
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
    // non-fatal
  }

  return { ok: true };
}
