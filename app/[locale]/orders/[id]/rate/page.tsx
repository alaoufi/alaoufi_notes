import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardHeader, CardTitle, CardBody } from "@syanah/ui";
import { RatingForm } from "@/features/ratings/components/rating-form";
import { Link } from "@/i18n/navigation";
import { type Locale } from "@/i18n/locales";

export const dynamic = "force-dynamic";

export default async function RateOrderPage({
  params,
}: {
  params: Promise<{ locale: string; id: string }>;
}) {
  const { locale: localeRaw, id } = await params;
  const locale = localeRaw as Locale;
  setRequestLocale(locale);
  const t = await getTranslations("ratings");
  const orders = await getTranslations("orders");

  return (
    <Container className="py-10">
      <nav className="mb-4 text-sm text-text-muted">
        <Link href="/orders" className="hover:text-text">
          {orders("title")}
        </Link>
        <span className="mx-2">›</span>
        <Link href={`/orders/${id}`} className="hover:text-text">
          {id}
        </Link>
        <span className="mx-2">›</span>
        <span className="text-text">{t("breadcrumb")}</span>
      </nav>

      <div className="mx-auto max-w-xl">
        <Card>
          <CardHeader>
            <CardTitle>{t("title")}</CardTitle>
          </CardHeader>
          <CardBody>
            <RatingForm />
          </CardBody>
        </Card>
      </div>
    </Container>
  );
}
