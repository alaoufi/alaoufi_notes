"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import { signInSchema, type SignInInput } from "../schema";

export interface SignInResult {
  ok: boolean;
  errorKey?: string;
  fieldErrors?: Record<string, string>;
}

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

  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.signInWithPassword(parsed.data);

  if (error) {
    return { ok: false, errorKey: "auth.errors.invalidCredentials" };
  }

  return { ok: true };
}
