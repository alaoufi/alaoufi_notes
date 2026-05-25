"use server";

import { revalidatePath } from "next/cache";
import {
  createSupabaseServerClient,
  createSupabaseServiceRoleClient,
} from "@/lib/supabase/server";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import { requireUser } from "@/lib/auth/guard";

export interface BootstrapStatus {
  hasAdmin: boolean;
  isSignedIn: boolean;
  configured: boolean;
}

export async function readBootstrapStatus(): Promise<BootstrapStatus> {
  if (!hasSupabaseEnv()) {
    return { hasAdmin: false, isSignedIn: false, configured: false };
  }

  const supabase = await createSupabaseServerClient();

  let isSignedIn = false;
  try {
    const { data } = await supabase.auth.getUser();
    isSignedIn = Boolean(data.user);
  } catch {
    isSignedIn = false;
  }

  // Try the RPC first (clean path). Fall back to a direct service-role query
  // when the RPC isn't installed yet — that lets /admin-setup work the moment
  // any user signs up, without forcing migrations 0023 to be applied first.
  let hasAdmin = false;
  try {
    const { data, error } = await supabase.rpc("has_any_super_admin" as never);
    if (!error && typeof data === "boolean") {
      hasAdmin = data;
    } else {
      // RPC missing — fall back via service_role.
      try {
        const admin = createSupabaseServiceRoleClient();
        const { data: rows } = await admin
          .from("user_roles" as never)
          .select("user_id")
          .eq("role", "super_admin")
          .limit(1);
        hasAdmin = Array.isArray(rows) && rows.length > 0;
      } catch {
        hasAdmin = false;
      }
    }
  } catch {
    hasAdmin = false;
  }

  return { hasAdmin, isSignedIn, configured: true };
}

export type BootstrapResult = { ok: true } | { ok: false; errorKey: string };

export async function bootstrapAdminAction(): Promise<BootstrapResult> {
  if (!hasSupabaseEnv()) {
    return { ok: false, errorKey: "adminSetup.errors.noBackend" };
  }
  const user = await requireUser();
  const supabase = await createSupabaseServerClient();

  // First try the clean RPC path.
  try {
    const { data, error } = await supabase.rpc("bootstrap_super_admin" as never);
    if (!error && data === true) {
      revalidatePath("/[locale]/admin-setup", "page");
      revalidatePath("/[locale]/admin", "layout");
      return { ok: true };
    }
    if (!error && data === false) {
      // Already-has-admin OR no auth — try service_role fallback to disambiguate.
    }
  } catch {
    // RPC not installed — fall through.
  }

  // Service-role fallback. Works even when migration 0023 hasn't been applied
  // yet, because it touches the table directly with the service key.
  try {
    const admin = createSupabaseServiceRoleClient();

    const { data: existingAdmins } = await admin
      .from("user_roles" as never)
      .select("user_id")
      .eq("role", "super_admin")
      .limit(1);

    if (Array.isArray(existingAdmins) && existingAdmins.length > 0) {
      return { ok: false, errorKey: "adminSetup.errors.adminExists" };
    }

    const { error: insertErr } = await admin
      .from("user_roles" as never)
      .insert({ user_id: user.id, role: "super_admin" } as never);

    if (insertErr) {
      return { ok: false, errorKey: "adminSetup.errors.rpcFailed" };
    }

    revalidatePath("/[locale]/admin-setup", "page");
    revalidatePath("/[locale]/admin", "layout");
    return { ok: true };
  } catch {
    return { ok: false, errorKey: "adminSetup.errors.rpcFailed" };
  }
}
