import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { Role } from "@/lib/supabase/types";

export async function getCurrentUser() {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) return null;
  return data.user;
}

export async function requireUser(returnTo?: string) {
  const user = await getCurrentUser();
  if (!user) {
    const path = returnTo ? `?returnTo=${encodeURIComponent(returnTo)}` : "";
    redirect(`/sign-in${path}`);
  }
  return user;
}

export async function getCurrentRoles(): Promise<Role[]> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.from("user_roles").select("role");
  if (error || !data) return [];
  return data.map((row) => row.role);
}

export async function requireRole(roles: Role | Role[]) {
  const allowed = Array.isArray(roles) ? roles : [roles];
  const user = await requireUser();
  const userRoles = await getCurrentRoles();
  if (!userRoles.some((r) => allowed.includes(r))) {
    redirect("/forbidden");
  }
  return user;
}

export async function hasRole(roles: Role | Role[]) {
  const allowed = Array.isArray(roles) ? roles : [roles];
  const userRoles = await getCurrentRoles();
  return userRoles.some((r) => allowed.includes(r));
}
