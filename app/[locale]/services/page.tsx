import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardBody } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { listCategories, localized } from "@/lib/catalog/queries";
import { CategoryIcon } from "@/components/category-icon";
import { type Locale } from "@/i18n/locales";

export default async function ServicesPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale: localeRaw } = await params;
  const locale = localeRaw as Locale;
  setRequestLocale(locale);
  const t = await getTranslations("services");
  const categories = await listCategories();

  return (
    <Container className="py-12">
      <header className="mb-10 flex flex-col gap-2">
        <h1 className="text-3xl font-bold text-text sm:text-4xl">{t("title")}</h1>
        <p className="text-text-muted">{t("subtitle")}</p>
      </header>

      <section aria-label={t("title")}>
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4">
          {categories.map((cat) => (
            <Link
              key={cat.slug}
              href={`/services/${cat.slug}`}
              className="group block focus:outline-none"
            >
              <Card className="h-full transition-shadow duration-base ease-standard group-hover:shadow-md">
                <CardBody className="flex flex-col items-start gap-3">
                  <span className="grid h-11 w-11 place-items-center rounded-md bg-primary/10 text-primary">
                    <CategoryIcon iconKey={cat.icon_key} className="h-5 w-5" />
                  </span>
                  <span className="font-semibold text-text">{localized(cat.name, locale)}</span>
                </CardBody>
              </Card>
            </Link>
          ))}
        </div>
      </section>
    </Container>
  );
}
