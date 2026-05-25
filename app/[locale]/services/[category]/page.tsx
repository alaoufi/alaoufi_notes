import { setRequestLocale, getTranslations } from "next-intl/server";
import { notFound } from "next/navigation";
import {
  Container,
  Card,
  CardBody,
  Badge,
  Button,
  CardHeader,
  CardTitle,
} from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { findCategoryBySlug, listCities, localized } from "@/lib/catalog/queries";
import { CategoryIcon } from "@/components/category-icon";
import { type Locale } from "@/i18n/locales";
import { Star } from "lucide-react";

export default async function CategoryPage({
  params,
}: {
  params: Promise<{ locale: string; category: string }>;
}) {
  const { locale: localeRaw, category: slug } = await params;
  const locale = localeRaw as Locale;
  setRequestLocale(locale);

  const category = await findCategoryBySlug(slug);
  if (!category) notFound();

  const t = await getTranslations("services");
  const cities = await listCities();

  return (
    <Container className="py-12">
      <nav className="mb-6 text-sm text-text-muted">
        <Link href="/services" className="hover:text-text">
          {t("title")}
        </Link>
        <span className="mx-2">›</span>
        <span className="text-text">{localized(category.name, locale)}</span>
      </nav>

      <header className="mb-10 flex items-start gap-4">
        <span className="grid h-14 w-14 place-items-center rounded-lg bg-primary/10 text-primary">
          <CategoryIcon iconKey={category.icon_key} className="h-7 w-7" />
        </span>
        <div>
          <h1 className="text-3xl font-bold text-text">{localized(category.name, locale)}</h1>
          <p className="mt-1 text-text-muted">{t("categorySubtitle")}</p>
        </div>
      </header>

      <div className="grid gap-8 lg:grid-cols-[260px_1fr]">
        <aside className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>{t("filters.city")}</CardTitle>
            </CardHeader>
            <CardBody>
              <ul className="flex flex-wrap gap-2">
                {cities.slice(0, 8).map((city) => (
                  <li key={city.slug}>
                    <Badge tone="neutral">{localized(city.name, locale)}</Badge>
                  </li>
                ))}
              </ul>
              <p className="mt-3 text-xs text-text-muted">{t("filters.fullListSoon")}</p>
            </CardBody>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>{t("filters.rating")}</CardTitle>
            </CardHeader>
            <CardBody>
              <ul className="space-y-1.5">
                {[5, 4, 3].map((r) => (
                  <li key={r} className="flex items-center gap-1 text-sm text-text-muted">
                    {Array.from({ length: r }).map((_, i) => (
                      <Star key={i} className="h-4 w-4 fill-warning text-warning" />
                    ))}
                    <span className="ms-1">{t("filters.starsAndUp", { stars: r })}</span>
                  </li>
                ))}
              </ul>
            </CardBody>
          </Card>
        </aside>

        <section>
          <Card>
            <CardBody className="flex flex-col items-center justify-center gap-3 py-16 text-center">
              <p className="text-lg font-semibold text-text">{t("noProvidersYet.title")}</p>
              <p className="max-w-md text-text-muted">{t("noProvidersYet.body")}</p>
              <Link href="/become-provider">
                <Button>{t("noProvidersYet.cta")}</Button>
              </Link>
            </CardBody>
          </Card>
        </section>
      </div>
    </Container>
  );
}
