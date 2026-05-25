"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";
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

  const { email, password, fullName, phone, role, locale } = parsed.data;
  const supabase = await createSupabaseServerClient();

  const { error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        full_name: fullName,
        phone_e164: phone,
        role,
        locale,
      },
    },
  });

  if (error) {
    if (error.message?.toLowerCase().includes("registered")) {
      throw new AuthError("USER_EXISTS", "auth.errors.userExists", error);
    }
    throw new AuthError("UNKNOWN", "auth.errors.unknown", error);
  }

  return { ok: true };
}
