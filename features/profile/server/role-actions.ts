"use server";

import { revalidatePath } from "next/cache";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import { requireUser } from "@/lib/auth/guard";

interface Result {
  ok: boolean;
  errorKey?: string;
}

export async function setActiveRoleAction(role: "requester" | "provider"): Promise<Result> {
  if (!hasSupabaseEnv()) {
    return { ok: false, errorKey: "auth.errors.noBackend" };
  }
  const user = await requireUser();
  const supabase = await createSupabaseServerClient();

  // Make sure the user actually holds this role first.
  const { data: held } = await supabase
    .from("user_roles" as never)
    .select("role")
    .eq("user_id", user.id)
    .eq("role", role)
    .maybeSingle();

  if (!held) {
    return { ok: false, errorKey: "profile.errors.roleNotHeld" };
  }

  const { error } = await supabase
    .from("profiles" as never)
    .update({ active_role: role } as never)
    .eq("user_id", user.id);

  if (error) return { ok: false, errorKey: "profile.errors.updateFailed" };

  revalidatePath("/[locale]/profile", "page");
  revalidatePath("/[locale]/dashboard", "page");
  return { ok: true };
}

export async function toggleSecondaryRoleAction(role: "requester" | "provider"): Promise<Result> {
  if (!hasSupabaseEnv()) {
    return { ok: false, errorKey: "auth.errors.noBackend" };
  }
  const user = await requireUser();
  const supabase = await createSupabaseServerClient();

  const { data: held } = await supabase
    .from("user_roles" as never)
    .select("role")
    .eq("user_id", user.id)
    .eq("role", role)
    .maybeSingle();

  if (held) {
    // Don't allow removing the last role.
    const { data: allRoles } = await supabase
      .from("user_roles" as never)
      .select("role")
      .eq("user_id", user.id);
    if ((allRoles?.length ?? 0) <= 1) {
      return { ok: false, errorKey: "profile.errors.cantRemoveLastRole" };
    }
    const { error } = await supabase
      .from("user_roles" as never)
      .delete()
      .eq("user_id", user.id)
      .eq("role", role);
    if (error) return { ok: false, errorKey: "profile.errors.updateFailed" };
  } else {
    const { error } = await supabase
      .from("user_roles" as never)
      .insert({ user_id: user.id, role } as never);
    if (error) return { ok: false, errorKey: "profile.errors.updateFailed" };
  }

  revalidatePath("/[locale]/profile", "page");
  revalidatePath("/[locale]/dashboard", "page");
  return { ok: true };
}
