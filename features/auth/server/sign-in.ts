"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import { signInSchema, type SignInInput, detectHandleKind } from "../schema";

export interface SignInResult {
  ok: boolean;
  errorKey?: string;
  fieldErrors?: Record<string, string>;
}

function synthesizeEmail(phoneE164: string): string {
  const digits = phoneE164.replace(/\D/g, "");
  return `${digits}@phone.syanah.app`;
}

/**
 * Accepts a single "handle" — username, phone, or email — plus password.
 * Resolves the handle to the underlying auth email through
 * resolve_signin_handle(), then calls signInWithPassword.
 */
export async function signInAction(input: SignInInput): Promise<SignInResult> {
  const parsed = signInSchema.safeParse(input);
  if (!parsed.success) {
    const fieldErrors: Record<string, string> = {};
    for (const issue of parsed.error.issues) {
      const key = issue.path[0]?.toString();
      if (key && !fieldErrors[key]) fieldErrors[key] = issue.message;
    }
    return { ok: false, errorKey: "auth.errors.invalidInput", fieldErrors };
  }

  if (!hasSupabaseEnv()) {
    return { ok: false, errorKey: "auth.errors.noBackend" };
  }

  const { handle, password } = parsed.data;
  const supabase = await createSupabaseServerClient();
  const kind = detectHandleKind(handle);

  let authEmail: string | null = null;
  let normalisedPhone: string | null = null;

  // 1) Try the helper RPC first.
  try {
    const { data: lookupRows } = await supabase.rpc(
      "resolve_signin_handle" as never,
      { p_handle: handle } as never,
    );
    const first = Array.isArray(lookupRows) ? lookupRows[0] : null;
    if (first) {
      const row = first as { email: string | null; phone_e164: string | null };
      authEmail = row.email ?? null;
      normalisedPhone = row.phone_e164 ?? null;
    }
  } catch {
    // RPC not yet available; fall through to format detection.
  }

  if (!authEmail) {
    if (kind === "email") {
      authEmail = handle.toLowerCase();
    } else if (kind === "phone") {
      const phone = handle.startsWith("+") ? handle : `+${handle.replace(/^00/, "")}`;
      normalisedPhone = phone;
    }
  }

  if (!authEmail && normalisedPhone) {
    authEmail = synthesizeEmail(normalisedPhone);
  }

  if (!authEmail) {
    return { ok: false, errorKey: "auth.errors.invalidCredentials" };
  }

  const { error } = await supabase.auth.signInWithPassword({ email: authEmail, password });
  if (error) return { ok: false, errorKey: "auth.errors.invalidCredentials" };
  return { ok: true };
}
