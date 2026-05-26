import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { requireRole, hasRole } from "@/lib/auth/guard";
import { getCurrentSections } from "@/lib/auth/sections";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import { type Locale } from "@/i18n/locales";
import {
  Shield,
  Tag,
  Users,
  MessageSquare,
  Settings,
  AlertTriangle,
  MapPin,
  KeyRound,
} from "lucide-react";

export const dynamic = "force-dynamic";

export default async function AdminLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);

  // When Supabase is configured we enforce the gate; when running in preview
  // (no env) we allow read-only access for visual verification.
  const configured = hasSupabaseEnv();
  if (configured) {
    await requireRole(["super_admin", "section_admin"]);
  }

  const sections = configured ? await getCurrentSections() : [];
  const isSuper = configured ? await hasRole("super_admin") : true;
  const can = (s: string) => !configured || sections.includes(s as never);

  const t = await getTranslations("admin");

  return (
    <Container className="py-8">
      <div className="grid gap-6 lg:grid-cols-[220px_1fr]">
        <aside className="space-y-1">
          <h2 className="mb-3 flex items-center gap-2 text-sm font-semibold text-text-muted uppercase tracking-wider">
            <Shield className="h-4 w-4" /> {t("nav.title")}
          </h2>
          <NavItem href="/admin" label={t("nav.overview")} icon={<Shield className="h-4 w-4" />} />
          {can("categories") && (
            <NavItem href="/admin/categories" label={t("nav.categories")} icon={<Tag className="h-4 w-4" />} />
          )}
          {can("geography") && (
            <NavItem href="/admin/regions" label={t("nav.regions")} icon={<MapPin className="h-4 w-4" />} />
          )}
          {can("users") && (
            <NavItem href="/admin/users" label={t("nav.users")} icon={<Users className="h-4 w-4" />} />
          )}
          {can("disputes") && (
            <NavItem
              href="/admin/disputes"
              label={t("nav.disputes")}
              icon={<AlertTriangle className="h-4 w-4" />}
            />
          )}
          {can("translations") && (
            <NavItem
              href="/admin/translations"
              label={t("nav.translations")}
              icon={<MessageSquare className="h-4 w-4" />}
            />
          )}
          {can("settings") && (
            <NavItem
              href="/admin/settings"
              label={t("nav.settings")}
              icon={<Settings className="h-4 w-4" />}
            />
          )}
          {isSuper && (
            <NavItem
              href="/admin/permissions"
              label={t("nav.permissions")}
              icon={<KeyRound className="h-4 w-4" />}
            />
          )}
        </aside>
        <section>{children}</section>
      </div>
    </Container>
  );
}

function NavItem({ href, label, icon }: { href: string; label: string; icon: React.ReactNode }) {
  return (
    <Link
      href={href}
      className="flex items-center gap-2 rounded-md px-3 py-2 text-sm text-text hover:bg-surface-muted"
    >
      <span className="text-text-muted">{icon}</span>
      <span>{label}</span>
    </Link>
  );
}
