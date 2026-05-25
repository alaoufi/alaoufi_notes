import { getTranslations } from "next-intl/server";
import { Container, Card, CardBody } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { listCategories, localized } from "@/lib/catalog/queries";
import { CategoryIcon } from "@/components/category-icon";
import type { Locale } from "@/i18n/locales";

export async function Categories({ locale }: { locale: Locale }) {
  const t = await getTranslations("categories");
  const categories = await listCategories();

  return (
    <section className="py-16">
      <Container>
        <div className="mb-10 flex flex-col gap-2">
          <h2 className="text-2xl font-bold text-text sm:text-3xl">{t("title")}</h2>
          <p className="text-text-muted">{t("subtitle")}</p>
        </div>
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4">
          {categories.map((cat) => (
            <Link
              key={cat.slug}
              href={`/services/${cat.slug}`}
              className="group block focus:outline-none"
            >
              <Card className="h-full transition-shadow duration-base ease-standard group-hover:shadow-md">
                <CardBody className="flex flex-col items-start gap-3">
                  <span className="grid h-10 w-10 place-items-center rounded-md bg-primary/10 text-primary">
                    <CategoryIcon iconKey={cat.icon_key} className="h-5 w-5" />
                  </span>
                  <span className="font-medium text-text">{localized(cat.name, locale)}</span>
                </CardBody>
              </Card>
            </Link>
          ))}
        </div>
      </Container>
    </section>
  );
}
