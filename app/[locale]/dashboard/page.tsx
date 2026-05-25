import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardHeader, CardTitle, CardBody, Badge, Button } from "@syanah/ui";
import { requireUser, getCurrentRoles } from "@/lib/auth/guard";
import { signOutAction } from "@/features/auth/server/sign-out";
import { type Locale } from "@/i18n/locales";

export const dynamic = "force-dynamic";

export default async function DashboardPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("dashboard");

  const user = await requireUser(`/${locale}/dashboard`);
  const roles = await getCurrentRoles();

  return (
    <Container className="py-12">
      <div className="mb-8 flex items-center justify-between">
        <h1 className="text-3xl font-bold text-text">{t("title")}</h1>
        <form action={signOutAction}>
          <Button type="submit" variant="outline">
            {t("signOut")}
          </Button>
        </form>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>{t("accountTitle")}</CardTitle>
          </CardHeader>
          <CardBody className="space-y-2">
            <Row label={t("email")} value={user.email ?? "—"} />
            <Row label={t("userId")} value={user.id} mono />
            <Row label={t("memberSince")} value={new Date(user.created_at).toLocaleDateString(locale)} />
          </CardBody>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>{t("rolesTitle")}</CardTitle>
          </CardHeader>
          <CardBody>
            {roles.length === 0 ? (
              <p className="text-text-muted">{t("noRoles")}</p>
            ) : (
              <div className="flex flex-wrap gap-2">
                {roles.map((r) => (
                  <Badge key={r} tone="primary">
                    {t(`roles.${r}`)}
                  </Badge>
                ))}
              </div>
            )}
          </CardBody>
        </Card>
      </div>
    </Container>
  );
}

function Row({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <div className="flex flex-col gap-0.5">
      <span className="text-xs text-text-muted">{label}</span>
      <span className={mono ? "font-mono text-sm break-all" : "text-text"}>{value}</span>
    </div>
  );
}
