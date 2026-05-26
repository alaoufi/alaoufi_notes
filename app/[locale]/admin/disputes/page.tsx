import { setRequestLocale, getTranslations } from "next-intl/server";
import { Card, CardBody, Badge, Button } from "@syanah/ui";
import { type Locale } from "@/i18n/locales";
import { requireAdminSection } from "@/lib/auth/sections";
import { hasSupabaseEnv } from "@/lib/supabase/env";

export const dynamic = "force-dynamic";

const SAMPLE = [
  {
    id: "d1",
    orderCode: "SY-2026-001234",
    openedBy: "أحمد العتيبي",
    reason: "الخدمة لم تكتمل",
    status: "open",
    age: "2h",
  },
  {
    id: "d2",
    orderCode: "SY-2026-001190",
    openedBy: "Provider · Khalid",
    reason: "الطالب لم يحضر",
    status: "under_review",
    age: "1d",
  },
];

export default async function AdminDisputesPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  if (hasSupabaseEnv()) await requireAdminSection("disputes");
  const t = await getTranslations("admin.disputes");

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold text-text">{t("title")}</h1>
        <p className="text-text-muted">{t("subtitle")}</p>
      </header>

      <div className="space-y-3">
        {SAMPLE.map((d) => (
          <Card key={d.id}>
            <CardBody className="flex flex-wrap items-center justify-between gap-3">
              <div className="space-y-1">
                <p className="font-mono text-xs text-text-muted">{d.orderCode}</p>
                <p className="font-semibold text-text">{d.reason}</p>
                <p className="text-sm text-text-muted">
                  {t("openedBy")}: {d.openedBy} · {d.age}
                </p>
              </div>
              <div className="flex items-center gap-2">
                <Badge tone={d.status === "open" ? "warning" : "info"}>
                  {t(`status.${d.status}`)}
                </Badge>
                <Button size="sm" variant="outline">{t("review")}</Button>
              </div>
            </CardBody>
          </Card>
        ))}
      </div>
    </div>
  );
}
