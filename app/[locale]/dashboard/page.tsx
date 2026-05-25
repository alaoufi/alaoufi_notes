import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Badge, Button } from "@syanah/ui";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import { getCurrentRoles, requireUser } from "@/lib/auth/guard";
import { signOutAction } from "@/features/auth/server/sign-out";
import { RequesterDashboard } from "@/features/dashboard/components/requester-dashboard";
import { ProviderDashboard } from "@/features/dashboard/components/provider-dashboard";
import { type Locale } from "@/i18n/locales";

export const dynamic = "force-dynamic";

export default async function DashboardPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("dashboard");

  // In preview (no Supabase), default to a requester dashboard so the layout
  // is demoable. In production the guard enforces auth.
  let role: "requester" | "provider" = "requester";
  let userLabel = "Demo user";

  if (hasSupabaseEnv()) {
    const user = await requireUser(`/${locale}/dashboard`);
    const roles = await getCurrentRoles();
    if (roles.includes("provider")) role = "provider";
    userLabel = user.email ?? user.id;
  }

  return (
    <Container className="py-10">
      <header className="mb-6 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-text sm:text-3xl">
            {role === "provider" ? t("provider.title") : t("requester.title")}
          </h1>
          <p className="text-sm text-text-muted">
            {userLabel} ·{" "}
            <Badge tone="primary">
              {role === "provider" ? t("roles.provider") : t("roles.requester")}
            </Badge>
          </p>
        </div>
        <form action={signOutAction}>
          <Button type="submit" variant="outline">
            {t("signOut")}
          </Button>
        </form>
      </header>

      {role === "provider" ? (
        <ProviderDashboard locale={locale} />
      ) : (
        <RequesterDashboard locale={locale} />
      )}
    </Container>
  );
}
