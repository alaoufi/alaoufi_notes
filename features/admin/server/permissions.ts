"use server";

import { revalidatePath } from "next/cache";
import {
  createSupabaseServerClient,
  createSupabaseServiceRoleClient,
} from "@/lib/supabase/server";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import { requireRole } from "@/lib/auth/guard";
import { type AdminSection, isAdminSection } from "@/lib/auth/sections";

interface Result {
  ok: boolean;
  errorKey?: string;
}

export async function grantSectionAction(
  userId: string,
  section: AdminSection,
): Promise<Result> {
  if (!hasSupabaseEnv()) {
    return { ok: false, errorKey: "admin.permissions.errors.noBackend" };
  }
  await requireRole("super_admin");
  if (!isAdminSection(section)) {
    return { ok: false, errorKey: "admin.permissions.errors.invalidSection" };
  }
  if (!userId || typeof userId !== "string") {
    return { ok: false, errorKey: "admin.permissions.errors.invalidUser" };
  }

  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc(
    "grant_admin_section" as never,
    { p_user: userId, p_section: section } as never,
  );
  if (error || data === false) {
    return { ok: false, errorKey: "admin.permissions.errors.grantFailed" };
  }
  revalidatePath("/[locale]/admin/permissions", "page");
  revalidatePath("/[locale]/admin", "layout");
  return { ok: true };
}

export async function revokeSectionAction(
  userId: string,
  section: AdminSection,
): Promise<Result> {
  if (!hasSupabaseEnv()) {
    return { ok: false, errorKey: "admin.permissions.errors.noBackend" };
  }
  await requireRole("super_admin");
  if (!isAdminSection(section)) {
    return { ok: false, errorKey: "admin.permissions.errors.invalidSection" };
  }

  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc(
    "revoke_admin_section" as never,
    { p_user: userId, p_section: section } as never,
  );
  if (error || data === false) {
    return { ok: false, errorKey: "admin.permissions.errors.revokeFailed" };
  }
  revalidatePath("/[locale]/admin/permissions", "page");
  revalidatePath("/[locale]/admin", "layout");
  return { ok: true };
}

export interface SectionAdminRow {
  userId: string;
  fullName: string | null;
  email: string | null;
  username: string | null;
  sections: AdminSection[];
}

export async function listSectionAdmins(): Promise<SectionAdminRow[]> {
  if (!hasSupabaseEnv()) return [];
  await requireRole("super_admin");
  const admin = createSupabaseServiceRoleClient();

  const { data: roleRows } = await admin
    .from("user_roles" as never)
    .select("user_id")
    .eq("role", "section_admin");

  const ids = Array.from(
    new Set(((roleRows ?? []) as { user_id: string }[]).map((r) => r.user_id)),
  );
  if (ids.length === 0) return [];

  const [{ data: grantRows }, { data: profileRows }] = await Promise.all([
    admin
      .from("admin_section_grants" as never)
      .select("user_id, section")
      .in("user_id", ids),
    admin
      .from("profiles" as never)
      .select("user_id, full_name, email_normalized, username")
      .in("user_id", ids),
  ]);

  const grantMap = new Map<string, AdminSection[]>();
  for (const row of ((grantRows ?? []) as {
    user_id: string;
    section: AdminSection;
  }[])) {
    if (!isAdminSection(row.section)) continue;
    const list = grantMap.get(row.user_id) ?? [];
    list.push(row.section);
    grantMap.set(row.user_id, list);
  }

  const profileMap = new Map<
    string,
    { full_name: string | null; email_normalized: string | null; username: string | null }
  >();
  for (const p of ((profileRows ?? []) as {
    user_id: string;
    full_name: string | null;
    email_normalized: string | null;
    username: string | null;
  }[])) {
    profileMap.set(p.user_id, {
      full_name: p.full_name,
      email_normalized: p.email_normalized,
      username: p.username,
    });
  }

  return ids
    .map((id) => {
      const p = profileMap.get(id);
      return {
        userId: id,
        fullName: p?.full_name ?? null,
        email: p?.email_normalized ?? null,
        username: p?.username ?? null,
        sections: grantMap.get(id) ?? [],
      };
    })
    .sort((a, b) => (a.fullName ?? a.username ?? a.email ?? "").localeCompare(
      b.fullName ?? b.username ?? b.email ?? "",
    ));
}

export interface UserSearchResult {
  userId: string;
  fullName: string | null;
  email: string | null;
  username: string | null;
}

export async function searchUsersForPromotion(
  query: string,
): Promise<UserSearchResult[]> {
  if (!hasSupabaseEnv()) return [];
  await requireRole("super_admin");
  const q = (query ?? "").trim();
  if (q.length < 2) return [];

  const admin = createSupabaseServiceRoleClient();
  const escaped = q.replace(/[%_,]/g, "");
  if (escaped.length === 0) return [];

  const { data, error } = await admin
    .from("profiles" as never)
    .select("user_id, full_name, email_normalized, username")
    .or(
      `username.ilike.%${escaped}%,email_normalized.ilike.%${escaped}%,full_name.ilike.%${escaped}%`,
    )
    .limit(15);
  if (error || !data) return [];
  return (data as {
    user_id: string;
    full_name: string | null;
    email_normalized: string | null;
    username: string | null;
  }[]).map((p) => ({
    userId: p.user_id,
    fullName: p.full_name,
    email: p.email_normalized,
    username: p.username,
  }));
}
