import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardBody, Button } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { OrderStatusBadge } from "@/features/orders/components/order-status-badge";
import { type Locale } from "@/i18n/locales";
import type { OrderSummary } from "@/features/orders/types";
import { Plus } from "lucide-react";

export const dynamic = "force-dynamic";

// Sample fallback data when no Supabase env (so the page renders meaningfully in preview).
const SAMPLE_ORDERS: OrderSummary[] = [
  {
    id: "ord-1",
    code: "SY-2026-001234",
    status: "in_progress",
    categorySlug: "hvac",
    categoryName: { ar: "تكييف وتبريد", en: "HVAC" },
    addressLabel: "حيّ النخيل، شارع الأمير سلطان",
    createdAt: new Date(Date.now() - 1000 * 60 * 90).toISOString(),
    total: 350,
  },
  {
    id: "ord-2",
    code: "SY-2026-001190",
    status: "completed",
    categorySlug: "plumbing",
    categoryName: { ar: "سباكة", en: "Plumbing" },
    addressLabel: "حيّ العزيزية",
    createdAt: new Date(Date.now() - 1000 * 60 * 60 * 24 * 3).toISOString(),
    total: 220,
  },
  {
    id: "ord-3",
    code: "SY-2026-001100",
    status: "pending",
    categorySlug: "electrical",
    categoryName: { ar: "كهرباء", en: "Electrical" },
    addressLabel: "حيّ الياسمين",
    createdAt: new Date(Date.now() - 1000 * 60 * 15).toISOString(),
    total: null,
  },
];

export default async function OrdersPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale: localeRaw } = await params;
  const locale = localeRaw as Locale;
  setRequestLocale(locale);
  const t = await getTranslations("orders");

  const orders = SAMPLE_ORDERS;

  return (
    <Container className="py-10">
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-3xl font-bold text-text">{t("title")}</h1>
        <Link href="/orders/new">
          <Button iconStart={<Plus className="h-4 w-4" />}>{t("newOrderCta")}</Button>
        </Link>
      </div>

      <div className="space-y-3">
        {orders.map((order) => (
          <Link key={order.id} href={`/orders/${order.id}`} className="block">
            <Card className="transition-shadow hover:shadow-md">
              <CardBody className="flex flex-wrap items-center justify-between gap-4">
                <div className="flex items-center gap-4">
                  <div className="flex flex-col">
                    <span className="text-xs font-mono text-text-muted">{order.code}</span>
                    <span className="font-semibold text-text">
                      {order.categoryName[locale] ?? order.categoryName.ar ?? order.categoryName.en}
                    </span>
                    <span className="text-sm text-text-muted">{order.addressLabel}</span>
                  </div>
                </div>
                <div className="flex items-center gap-4">
                  {order.total != null && (
                    <span className="font-semibold text-text">
                      {order.total} {t("currency")}
                    </span>
                  )}
                  <OrderStatusBadge status={order.status} />
                </div>
              </CardBody>
            </Card>
          </Link>
        ))}
      </div>
    </Container>
  );
}
