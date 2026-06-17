import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { getCurrentRoles, requireUser } from "./guard";
import { ADMIN_SECTIONS, isAdminSection, type AdminSection } from "./sections-shared";

// Re-export the client-safe constants/types so existing server-side importers
// (`@/lib/auth/sections`) keep working unchanged. Client Components should
// import them from `./sections-shared` directly.
export { ADMIN_SECTIONS, isAdminSection };
export type { AdminSection };

/**
 * Every admin section the current user can access.
 *  super_admin    → all sections
 *  section_admin  → only sections present in admin_section_grants
 *  anyone else    → []
 */
export async function getCurrentSections(): Promise<AdminSection[]> {
  const roles = await getCurrentRoles();
  if (roles.includes("super_admin")) return [...ADMIN_SECTIONS];
  if (!roles.includes("section_admin")) return [];

  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("admin_section_grants" as never)
    .select("section");
  if (error || !data) return [];
  return (data as { section: AdminSection }[])
    .map((r) => r.section)
    .filter(isAdminSection);
}

export async function hasAdminSection(section: AdminSection): Promise<boolean> {
  const sections = await getCurrentSections();
  return sections.includes(section);
}

export async function requireAdminSection(section: AdminSection) {
  const user = await requireUser();
  const allowed = await hasAdminSection(section);
  if (!allowed) redirect("/forbidden");
  return user;
}
