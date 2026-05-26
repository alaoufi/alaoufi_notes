"use server";

import { revalidatePath } from "next/cache";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import { requireAdminSection } from "@/lib/auth/sections";

interface Result {
  ok: boolean;
  errorKey?: string;
}

/**
 * Activate or deactivate a region by id. Cascades to governorates + cities via
 * the database triggers in migration 0016.
 *
 * Requires super_admin. When Supabase isn't configured we no-op gracefully so
 * the admin UI is still navigable in preview mode.
 */
export async function setRegionActive(regionId: string, isActive: boolean): Promise<Result> {
  if (!hasSupabaseEnv()) {
    return { ok: false, errorKey: "admin.regions.errors.noBackend" };
  }
  await requireAdminSection("geography");
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase
    .from("regions" as never)
    .update({ is_active: isActive } as never)
    .eq("id", regionId);
  if (error) return { ok: false, errorKey: "admin.regions.errors.updateFailed" };

  revalidatePath("/[locale]/admin/regions", "page");
  return { ok: true };
}

/**
 * Activate or deactivate a single governorate. Cascades to its cities.
 */
export async function setGovernorateActive(
  governorateId: string,
  isActive: boolean,
): Promise<Result> {
  if (!hasSupabaseEnv()) {
    return { ok: false, errorKey: "admin.regions.errors.noBackend" };
  }
  await requireAdminSection("geography");
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase
    .from("governorates" as never)
    .update({ is_active: isActive } as never)
    .eq("id", governorateId);
  if (error) return { ok: false, errorKey: "admin.regions.errors.updateFailed" };

  revalidatePath("/[locale]/admin/regions", "page");
  return { ok: true };
}
