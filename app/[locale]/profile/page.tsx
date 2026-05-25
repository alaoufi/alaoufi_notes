import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardHeader, CardTitle, CardBody, Input, Button } from "@syanah/ui";
import { type Locale } from "@/i18n/locales";

export const dynamic = "force-dynamic";

export default async function ProfilePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("profile");

  return (
    <Container className="py-10">
      <header className="mb-6">
        <h1 className="text-2xl font-bold text-text">{t("title")}</h1>
        <p className="text-sm text-text-muted">{t("subtitle")}</p>
      </header>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader><CardTitle>{t("personal")}</CardTitle></CardHeader>
          <CardBody className="space-y-4">
            <Input label={t("fullName")} defaultValue="" placeholder={t("fullNamePlaceholder")} />
            <Input label={t("email")} type="email" defaultValue="" />
            <Input label={t("phone")} type="tel" defaultValue="" dir="ltr" />
            <Button>{t("save")}</Button>
          </CardBody>
        </Card>

        <Card>
          <CardHeader><CardTitle>{t("address")}</CardTitle></CardHeader>
          <CardBody className="space-y-3">
            <p className="text-sm text-text-muted">{t("addressNote")}</p>
            <p className="rounded-md border border-dashed border-border p-3 text-sm text-text-muted">
              {t("addressEditNote")}
            </p>
          </CardBody>
        </Card>
      </div>
    </Container>
  );
}
