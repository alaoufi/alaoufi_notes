import { setRequestLocale, getTranslations } from "next-intl/server";
import { type Locale } from "@/i18n/locales";
import { requireRole } from "@/lib/auth/guard";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import { Card, CardBody } from "@syanah/ui";
import { listSectionAdmins } from "@/features/admin/server/permissions";
import { PermissionsEditor } from "@/features/admin/components/permissions-editor";
import { AlertCircle } from "lucide-react";

export const dynamic = "force-dynamic";

export default async function AdminPermissionsPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);

  if (hasSupabaseEnv()) {
    await requireRole("super_admin");
  }

  const t = await getTranslations("admin.permissions");
  const rows = hasSupabaseEnv() ? await listSectionAdmins() : [];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold text-text">{t("title")}</h1>
        <p className="text-text-muted">{t("subtitle")}</p>
      </header>

      {!hasSupabaseEnv() && (
        <Card>
          <CardBody className="flex items-center gap-2 text-warning">
            <AlertCircle className="h-5 w-5" />
            <span className="text-sm">{t("errors.noBackend")}</span>
          </CardBody>
        </Card>
      )}

      {hasSupabaseEnv() && <PermissionsEditor initialRows={rows} />}
    </div>
  );
}
