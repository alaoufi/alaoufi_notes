import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardBody, Badge } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { listCategories, listCities, localized } from "@/lib/catalog/queries";
import { CategoryIcon } from "@/components/category-icon";
import { type Locale } from "@/i18n/locales";
import { Search } from "lucide-react";

export default async function ProvidersPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ q?: string; category?: string; city?: string }>;
}) {
  const { locale: localeRaw } = await params;
  const sp = await searchParams;
  const locale = localeRaw as Locale;
  setRequestLocale(locale);

  const t = await getTranslations("providersList");
  const common = await getTranslations("common");
  const [categories, cities] = await Promise.all([listCategories(), listCities()]);

  return (
    <Container className="py-12">
      <header className="mb-8 flex flex-col gap-2">
        <h1 className="text-3xl font-bold text-text sm:text-4xl">{t("title")}</h1>
        <p className="text-text-muted">{t("subtitle")}</p>
      </header>

      <form action="" method="get" className="mb-10 flex flex-col gap-3 sm:flex-row">
        <label className="relative flex-1">
          <span className="sr-only">{common("search")}</span>
          <Search
            className="pointer-events-none absolute start-3 top-1/2 h-5 w-5 -translate-y-1/2 text-text-muted"
            aria-hidden
          />
          <input
            type="search"
            name="q"
            defaultValue={sp.q ?? ""}
            placeholder={t("searchPlaceholder")}
            className="h-12 w-full rounded-md border border-border bg-surface ps-10 pe-3 text-text outline-none focus:border-primary"
          />
        </label>
        <select
          name="category"
          defaultValue={sp.category ?? ""}
          className="h-12 rounded-md border border-border bg-surface px-3 text-text outline-none focus:border-primary"
        >
          <option value="">{t("anyCategory")}</option>
          {categories.map((c) => (
            <option key={c.slug} value={c.slug}>
              {localized(c.name, locale)}
            </option>
          ))}
        </select>
        <select
          name="city"
          defaultValue={sp.city ?? ""}
          className="h-12 rounded-md border border-border bg-surface px-3 text-text outline-none focus:border-primary"
        >
          <option value="">{t("anyCity")}</option>
          {cities.map((c) => (
            <option key={c.slug} value={c.slug}>
              {localized(c.name, locale)}
            </option>
          ))}
        </select>
        <button
          type="submit"
          className="h-12 rounded-md bg-primary px-6 text-sm font-medium text-primary-contrast hover:bg-primary-hover"
        >
          {common("search")}
        </button>
      </form>

      <Card>
        <CardBody className="py-12 text-center">
          <p className="text-lg font-semibold text-text">{t("emptyTitle")}</p>
          <p className="mt-2 text-text-muted">{t("emptyBody")}</p>
          <div className="mt-6 flex flex-wrap items-center justify-center gap-2">
            {categories.slice(0, 4).map((c) => (
              <Link
                key={c.slug}
                href={`/services/${c.slug}`}
              >
                <Badge tone="primary" className="cursor-pointer">
                  <span className="me-1">
                    <CategoryIcon iconKey={c.icon_key} className="h-3 w-3" />
                  </span>
                  {localized(c.name, locale)}
                </Badge>
              </Link>
            ))}
          </div>
        </CardBody>
      </Card>
    </Container>
  );
}
