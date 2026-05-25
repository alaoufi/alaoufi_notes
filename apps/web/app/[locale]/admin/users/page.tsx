import { setRequestLocale, getTranslations } from "next-intl/server";
import { Card, CardBody, Badge, Input } from "@syanah/ui";
import { type Locale } from "@/i18n/locales";

export const dynamic = "force-dynamic";

const SAMPLE = [
  { name: "أحمد العتيبي", role: "provider", verified: true,  city: "الرياض", joined: "2025-11-02" },
  { name: "نورة الزهراني", role: "requester", verified: true, city: "جدّة", joined: "2025-12-14" },
  { name: "خالد الشمري",  role: "provider", verified: false, city: "الدمام", joined: "2026-01-08" },
];

export default async function AdminUsersPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("admin.users");

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold text-text">{t("title")}</h1>
        <p className="text-text-muted">{t("subtitle")}</p>
      </header>

      <Card>
        <CardBody className="space-y-4">
          <Input placeholder={t("searchPlaceholder")} />
          <div className="divide-y divide-border">
            {SAMPLE.map((u, i) => (
              <div key={i} className="flex items-center justify-between py-3">
                <div>
                  <p className="font-medium text-text">{u.name}</p>
                  <p className="text-xs text-text-muted">{u.city} · {u.joined}</p>
                </div>
                <div className="flex items-center gap-2">
                  <Badge tone={u.role === "provider" ? "primary" : "neutral"}>
                    {t(`role.${u.role}`)}
                  </Badge>
                  <Badge tone={u.verified ? "success" : "warning"}>
                    {u.verified ? t("verified") : t("unverified")}
                  </Badge>
                </div>
              </div>
            ))}
          </div>
        </CardBody>
      </Card>
    </div>
  );
}
