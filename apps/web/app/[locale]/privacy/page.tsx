import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container } from "@syanah/ui";
import { type Locale } from "@/i18n/locales";

export default async function PrivacyPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("footer");
  const common = await getTranslations("common");

  return (
    <Container className="py-16">
      <h1 className="text-3xl font-bold text-text">{t("privacy")}</h1>
      <p className="mt-4 text-text-muted">{common("comingSoon")}</p>
    </Container>
  );
}
