import { setRequestLocale, getTranslations } from "next-intl/server";
import { Card, CardHeader, CardTitle, CardBody, Input, Button } from "@syanah/ui";
import { type Locale } from "@/i18n/locales";
import { requireAdminSection } from "@/lib/auth/sections";
import { hasSupabaseEnv } from "@/lib/supabase/env";

export const dynamic = "force-dynamic";

export default async function AdminSettingsPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  if (hasSupabaseEnv()) await requireAdminSection("settings");
  const t = await getTranslations("admin.settings");

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold text-text">{t("title")}</h1>
        <p className="text-text-muted">{t("subtitle")}</p>
      </header>

      <Card>
        <CardHeader><CardTitle>{t("appTitle")}</CardTitle></CardHeader>
        <CardBody className="space-y-4">
          <Input label={t("defaultLocale")} defaultValue="ar" />
          <Input label={t("defaultTheme")} defaultValue="navy" />
          <Input label={t("cancelWindow")} type="number" defaultValue={5} hint={t("cancelWindowHint")} />
          <Input label={t("disputesWindow")} type="number" defaultValue={72} hint={t("disputesWindowHint")} />
        </CardBody>
      </Card>

      <Card>
        <CardHeader><CardTitle>{t("apiKeysTitle")}</CardTitle></CardHeader>
        <CardBody className="space-y-4">
          <p className="text-sm text-text-muted">{t("apiKeysIntro")}</p>
          <Input label="Google Maps API key" type="password" placeholder="•••••" />
          <Input label="SMS provider API key" type="password" placeholder="•••••" />
          <Input label="Payments webhook secret" type="password" placeholder="•••••" />
          <p className="text-xs text-text-muted">{t("apiKeysHint")}</p>
        </CardBody>
      </Card>

      <div className="flex justify-end">
        <Button>{t("save")}</Button>
      </div>
    </div>
  );
}
