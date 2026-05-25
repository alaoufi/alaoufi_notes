import { useTranslations } from "next-intl";
import { Container, Button } from "@syanah/ui";
import { Link } from "@/i18n/navigation";

export function ProvidersCta() {
  const t = useTranslations("providersCta");

  return (
    <section className="py-16">
      <Container>
        <div className="overflow-hidden rounded-xl border border-border bg-surface-strong p-8 text-text-inverse shadow-lg sm:p-12">
          <div className="flex flex-col items-start gap-6 md:flex-row md:items-center md:justify-between">
            <div className="max-w-2xl">
              <h2 className="text-2xl font-bold sm:text-3xl">{t("title")}</h2>
              <p className="mt-3 text-text-inverse/80">{t("body")}</p>
            </div>
            <Link href="/become-provider">
              <Button size="lg" variant="primary" className="bg-primary-contrast text-text hover:bg-primary-contrast/90">
                {t("cta")}
              </Button>
            </Link>
          </div>
        </div>
      </Container>
    </section>
  );
}
