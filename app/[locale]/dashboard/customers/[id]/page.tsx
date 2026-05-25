import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardHeader, CardTitle, CardBody, Button, Badge, Input } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { Phone, MessageCircle, Star, ArrowLeft, Calendar } from "lucide-react";
import { type Locale } from "@/i18n/locales";

export const dynamic = "force-dynamic";

const SAMPLE = {
  "c-1": {
    name: "نورة الزهراني",
    phone: "+966500000001",
    orders: 4,
    completed: 4,
    avgRating: 4.8,
    note: "تفضّل المواعيد المسائية بعد المغرب",
    history: [
      { date: "2026-04-21", category: "تكييف", code: "SY-2026-001234", status: "مكتمل" },
      { date: "2026-03-12", category: "تكييف", code: "SY-2026-001102", status: "مكتمل" },
      { date: "2026-01-30", category: "كهرباء", code: "SY-2026-001054", status: "مكتمل" },
      { date: "2025-12-04", category: "تكييف", code: "SY-2025-000932", status: "مكتمل" },
    ],
  },
  "c-2": {
    name: "محمد القحطاني",
    phone: "+966500000002",
    orders: 2,
    completed: 2,
    avgRating: 4.5,
    note: "",
    history: [
      { date: "2026-04-15", category: "سباكة", code: "SY-2026-001190", status: "مكتمل" },
      { date: "2025-11-20", category: "سباكة", code: "SY-2025-000880", status: "مكتمل" },
    ],
  },
} as const;

export default async function CustomerDetailPage({
  params,
}: {
  params: Promise<{ locale: string; id: string }>;
}) {
  const { locale: localeRaw, id } = await params;
  const locale = localeRaw as Locale;
  setRequestLocale(locale);
  void locale;
  const t = await getTranslations("customerDetail");
  const list = await getTranslations("dashboard.customers");

  const customer = (SAMPLE as Record<string, (typeof SAMPLE)[keyof typeof SAMPLE]>)[id];

  if (!customer) {
    return (
      <Container className="py-16">
        <Card>
          <CardBody className="py-16 text-center">
            <p className="text-text">{t("notFound")}</p>
            <Link href="/dashboard/customers" className="mt-4 inline-block">
              <Button variant="outline" iconStart={<ArrowLeft className="h-4 w-4 rtl:rotate-180" />}>
                {t("backToList")}
              </Button>
            </Link>
          </CardBody>
        </Card>
      </Container>
    );
  }

  return (
    <Container className="py-10">
      <nav className="mb-4 text-sm text-text-muted">
        <Link href="/dashboard" className="hover:text-text">
          {t("dashboard")}
        </Link>
        <span className="mx-2">›</span>
        <Link href="/dashboard/customers" className="hover:text-text">
          {list("title")}
        </Link>
        <span className="mx-2">›</span>
        <span className="text-text">{customer.name}</span>
      </nav>

      <div className="grid gap-6 lg:grid-cols-[1fr_320px]">
        <div className="space-y-6">
          <Card>
            <CardBody className="space-y-3">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <h1 className="text-2xl font-bold text-text">{customer.name}</h1>
                  <p className="mt-1 text-sm text-text-muted" dir="ltr">
                    {customer.phone}
                  </p>
                </div>
                <div className="flex items-center gap-1">
                  <Star className="h-4 w-4 fill-warning text-warning" />
                  <span className="font-semibold text-text">{customer.avgRating}</span>
                </div>
              </div>

              <div className="flex flex-wrap items-center gap-3 border-t border-border pt-3">
                <Badge tone="primary">{list("ordersCount", { count: customer.orders })}</Badge>
                <Badge tone="success">{t("completed", { count: customer.completed })}</Badge>
              </div>

              <div className="flex gap-2 pt-2">
                <Button size="sm" iconStart={<Phone className="h-4 w-4" />}>{list("call")}</Button>
                <Button size="sm" variant="outline" iconStart={<MessageCircle className="h-4 w-4" />}>
                  {list("message")}
                </Button>
              </div>
            </CardBody>
          </Card>

          <Card>
            <CardHeader><CardTitle>{t("history")}</CardTitle></CardHeader>
            <CardBody>
              <ul className="divide-y divide-border">
                {customer.history.map((h) => (
                  <li key={h.code} className="flex items-center justify-between gap-3 py-3">
                    <div className="flex items-center gap-3">
                      <Calendar className="h-4 w-4 text-text-muted" />
                      <div>
                        <p className="font-mono text-xs text-text-muted">{h.code}</p>
                        <p className="text-text">{h.category}</p>
                        <p className="text-xs text-text-muted">{h.date}</p>
                      </div>
                    </div>
                    <Badge tone="success">{h.status}</Badge>
                  </li>
                ))}
              </ul>
            </CardBody>
          </Card>
        </div>

        <aside className="space-y-4">
          <Card>
            <CardHeader><CardTitle>{t("myNote")}</CardTitle></CardHeader>
            <CardBody className="space-y-3">
              <p className="text-xs text-text-muted">{t("myNoteHint")}</p>
              <Input defaultValue={customer.note} placeholder={t("notePlaceholder")} />
              <Button size="sm" fullWidth>{t("saveNote")}</Button>
            </CardBody>
          </Card>
        </aside>
      </div>
    </Container>
  );
}
