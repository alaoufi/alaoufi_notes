import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container } from "@syanah/ui";
import { NewOrderForm } from "@/features/orders/components/new-order-form";
import { listCategories, listCities } from "@/lib/catalog/queries";
import { type Locale } from "@/i18n/locales";

export default async function NewOrderPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("orders.new");
  const [categories, cities] = await Promise.all([listCategories(), listCities()]);

  return (
    <Container className="py-10">
      <h1 className="mb-2 text-3xl font-bold text-text">{t("title")}</h1>
      <p className="mb-8 text-text-muted">{t("subtitle")}</p>
      <NewOrderForm categories={categories} cities={cities} locale={locale as Locale} />
    </Container>
  );
}
