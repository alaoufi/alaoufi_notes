import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Button } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { type Locale } from "@/i18n/locales";

export default async function ForbiddenPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("auth");

  return (
    <Container className="py-24">
      <div className="mx-auto max-w-md text-center">
        <h1 className="text-2xl font-bold text-text">{t("forbidden.title")}</h1>
        <p className="mt-3 text-text-muted">{t("forbidden.body")}</p>
        <Link href="/" className="mt-6 inline-block">
          <Button variant="outline">{t("forbidden.cta")}</Button>
        </Link>
      </div>
    </Container>
  );
}
