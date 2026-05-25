import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardHeader, CardTitle, CardBody } from "@syanah/ui";
import { type Locale } from "@/i18n/locales";

export default async function BecomeProviderPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("providersCta");
  const common = await getTranslations("common");

  return (
    <Container className="py-16">
      <div className="mx-auto max-w-2xl">
        <Card>
          <CardHeader>
            <CardTitle>{t("title")}</CardTitle>
          </CardHeader>
          <CardBody className="space-y-3">
            <p className="text-text-muted">{t("body")}</p>
            <p className="text-sm text-text-muted">{common("comingSoon")}</p>
          </CardBody>
        </Card>
      </div>
    </Container>
  );
}
