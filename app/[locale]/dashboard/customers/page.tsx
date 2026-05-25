import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardBody, Input, Badge, Button } from "@syanah/ui";
import { Search, Phone, MessageCircle, Star } from "lucide-react";
import { type Locale } from "@/i18n/locales";

export const dynamic = "force-dynamic";

const SAMPLE = [
  { id: "c-1", name: "نورة الزهراني", phone: "+966500000001", orders: 4, lastAt: "منذ ٤ أيام",   rating: 4.8, note: "تفضّل المواعيد المسائية" },
  { id: "c-2", name: "محمد القحطاني", phone: "+966500000002", orders: 2, lastAt: "منذ أسبوع",     rating: 4.5, note: "" },
  { id: "c-3", name: "فاطمة العتيبي", phone: "+966500000003", orders: 1, lastAt: "منذ شهر",       rating: 5.0, note: "" },
  { id: "c-4", name: "خالد الشمري",  phone: "+966500000004", orders: 3, lastAt: "منذ شهرين",     rating: 4.2, note: "حيّ الياسمين" },
];

export default async function CustomersPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("dashboard.customers");
  const common = await getTranslations("common");

  return (
    <Container className="py-10">
      <header className="mb-6">
        <h1 className="text-2xl font-bold text-text">{t("title")}</h1>
        <p className="text-sm text-text-muted">{t("subtitle")}</p>
      </header>

      <Card className="mb-4">
        <CardBody>
          <Input
            placeholder={t("searchPlaceholder")}
            iconStart={<Search className="h-4 w-4" />}
          />
        </CardBody>
      </Card>

      <div className="grid gap-3 sm:grid-cols-2">
        {SAMPLE.map((c) => (
          <Card key={c.id}>
            <CardBody className="space-y-3">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-lg font-semibold text-text">{c.name}</p>
                  <p className="text-xs text-text-muted" dir="ltr">{c.phone}</p>
                </div>
                <div className="text-end">
                  <p className="flex items-center gap-1 text-sm text-text">
                    <Star className="h-3.5 w-3.5 fill-warning text-warning" />
                    {c.rating}
                  </p>
                  <Badge tone="neutral">{t("ordersCount", { count: c.orders })}</Badge>
                </div>
              </div>
              <p className="text-xs text-text-muted">{c.lastAt}</p>
              {c.note && (
                <p className="rounded-md bg-surface-muted/60 p-2 text-xs text-text">
                  📝 {c.note}
                </p>
              )}
              <div className="flex gap-2">
                <Button size="sm" variant="outline" iconStart={<Phone className="h-3.5 w-3.5" />}>
                  {t("call")}
                </Button>
                <Button size="sm" variant="outline" iconStart={<MessageCircle className="h-3.5 w-3.5" />}>
                  {t("message")}
                </Button>
                <Button size="sm" variant="ghost">{common("save")}</Button>
              </div>
            </CardBody>
          </Card>
        ))}
      </div>
    </Container>
  );
}
