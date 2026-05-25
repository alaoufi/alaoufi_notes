import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardHeader, CardTitle, CardBody, Badge, Button } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { readBootstrapStatus } from "@/features/admin/server/bootstrap-admin";
import { BootstrapAdminButton } from "@/features/admin/components/bootstrap-admin-button";
import { type Locale } from "@/i18n/locales";
import { ShieldCheck, AlertCircle, LogIn, Database } from "lucide-react";

export const dynamic = "force-dynamic";

export default async function AdminSetupPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("adminSetup");
  const status = await readBootstrapStatus();

  return (
    <Container className="py-16">
      <div className="mx-auto max-w-xl space-y-6">
        <header className="text-center">
          <div className="mx-auto mb-4 grid h-16 w-16 place-items-center rounded-pill bg-primary/10 text-primary">
            <ShieldCheck className="h-8 w-8" />
          </div>
          <h1 className="text-2xl font-bold text-text sm:text-3xl">{t("title")}</h1>
          <p className="mt-2 text-text-muted">{t("subtitle")}</p>
        </header>

        <Card>
          <CardHeader>
            <CardTitle>{t("statusTitle")}</CardTitle>
          </CardHeader>
          <CardBody className="space-y-4">
            {/* Step 1: Backend configured */}
            <Row
              icon={<Database className="h-5 w-5" />}
              label={t("steps.backend")}
              ok={status.configured}
              okLabel={t("steps.backendOk")}
              failLabel={t("steps.backendFail")}
            />

            {/* Step 2: Signed in */}
            <Row
              icon={<LogIn className="h-5 w-5" />}
              label={t("steps.signedIn")}
              ok={status.isSignedIn}
              okLabel={t("steps.signedInOk")}
              failLabel={t("steps.signedInFail")}
              extra={
                !status.isSignedIn && status.configured ? (
                  <Link href="/sign-in" className="text-sm text-primary hover:underline">
                    {t("goSignIn")} →
                  </Link>
                ) : null
              }
            />

            {/* Step 3: Admin slot available */}
            <Row
              icon={<ShieldCheck className="h-5 w-5" />}
              label={t("steps.slotAvailable")}
              ok={!status.hasAdmin && status.configured}
              okLabel={t("steps.slotAvailableOk")}
              failLabel={t("steps.slotTaken")}
            />
          </CardBody>
        </Card>

        {/* Action card */}
        {status.configured && status.isSignedIn && !status.hasAdmin && (
          <Card>
            <CardHeader>
              <CardTitle>{t("actionTitle")}</CardTitle>
            </CardHeader>
            <CardBody className="space-y-4">
              <p className="text-sm text-text-muted">{t("actionBody")}</p>
              <BootstrapAdminButton />
              <p className="rounded-md border border-dashed border-border p-3 text-xs text-text-muted">
                {t("oneShot")}
              </p>
            </CardBody>
          </Card>
        )}

        {/* Already an admin */}
        {status.hasAdmin && (
          <Card>
            <CardBody className="space-y-3 text-center">
              <Badge tone="success">{t("alreadyAdmin")}</Badge>
              <p className="text-sm text-text-muted">{t("alreadyAdminBody")}</p>
              <Link href="/admin" className="inline-block">
                <Button>{t("openAdmin")}</Button>
              </Link>
            </CardBody>
          </Card>
        )}

        {!status.configured && (
          <Card>
            <CardBody className="space-y-2 text-center">
              <div className="mx-auto grid h-12 w-12 place-items-center rounded-pill bg-danger/10 text-danger">
                <AlertCircle className="h-6 w-6" />
              </div>
              <p className="font-medium text-text">{t("notConfigured")}</p>
              <p className="text-sm text-text-muted">{t("notConfiguredBody")}</p>
            </CardBody>
          </Card>
        )}
      </div>
    </Container>
  );
}

function Row({
  icon,
  label,
  ok,
  okLabel,
  failLabel,
  extra,
}: {
  icon: React.ReactNode;
  label: string;
  ok: boolean;
  okLabel: string;
  failLabel: string;
  extra?: React.ReactNode;
}) {
  return (
    <div className="flex items-start justify-between gap-3 rounded-md border border-border p-3">
      <div className="flex items-start gap-3">
        <span className={ok ? "mt-0.5 text-success" : "mt-0.5 text-text-muted"}>{icon}</span>
        <div>
          <p className="font-medium text-text">{label}</p>
          <p className={`text-xs ${ok ? "text-success" : "text-text-muted"}`}>
            {ok ? okLabel : failLabel}
          </p>
          {extra && <div className="mt-1">{extra}</div>}
        </div>
      </div>
      <Badge tone={ok ? "success" : "neutral"}>{ok ? "✓" : "—"}</Badge>
    </div>
  );
}
