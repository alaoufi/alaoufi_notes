import { setRequestLocale, getTranslations } from "next-intl/server";
import { Card, CardHeader, CardTitle, CardBody, Badge } from "@syanah/ui";
import { type Locale } from "@/i18n/locales";

export const dynamic = "force-dynamic";

const KPIS = [
  { key: "ordersToday", value: "47", trend: "+18%" },
  { key: "activeProviders", value: "312", trend: "+5%" },
  { key: "openDisputes", value: "4", trend: "-2" },
  { key: "monthlyRevenue", value: "62,400 ر.س", trend: "+11%" },
];

export default async function AdminOverviewPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("admin.overview");

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold text-text">{t("title")}</h1>
        <p className="text-text-muted">{t("subtitle")}</p>
      </header>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {KPIS.map((k) => (
          <Card key={k.key}>
            <CardBody>
              <p className="text-xs text-text-muted">{t(`kpi.${k.key}`)}</p>
              <p className="mt-1 text-2xl font-bold text-text">{k.value}</p>
              <Badge tone={k.trend.startsWith("-") ? "danger" : "success"} className="mt-2">
                {k.trend}
              </Badge>
            </CardBody>
          </Card>
        ))}
      </div>

      <Card>
        <CardHeader>
          <CardTitle>{t("recentActivity")}</CardTitle>
        </CardHeader>
        <CardBody>
          <p className="text-sm text-text-muted">{t("recentActivityBody")}</p>
        </CardBody>
      </Card>
    </div>
  );
}
