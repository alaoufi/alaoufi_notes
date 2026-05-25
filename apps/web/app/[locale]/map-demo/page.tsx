import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardHeader, CardTitle, CardBody } from "@syanah/ui";
import { LocationPicker } from "@/components/map/location-picker";
import { type Locale } from "@/i18n/locales";

export default async function MapDemoPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("mapDemo");

  return (
    <Container className="py-12">
      <h1 className="mb-2 text-3xl font-bold text-text">{t("title")}</h1>
      <p className="mb-8 text-text-muted">{t("subtitle")}</p>

      <Card>
        <CardHeader>
          <CardTitle>{t("pickerTitle")}</CardTitle>
        </CardHeader>
        <CardBody>
          <LocationPicker height={420} />
          <p className="mt-3 text-sm text-text-muted">{t("pickerHint")}</p>
        </CardBody>
      </Card>
    </Container>
  );
}
