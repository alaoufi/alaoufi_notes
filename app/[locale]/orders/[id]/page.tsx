import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardHeader, CardTitle, CardBody, Button } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { OrderStatusBadge } from "@/features/orders/components/order-status-badge";
import { OrderTimeline } from "@/features/orders/components/order-timeline";
import { TrackingMap } from "@/components/map/tracking-map";
import { ChatThread } from "@/features/chat/components/chat-thread";
import { type Locale } from "@/i18n/locales";
import type { OrderStatus } from "@/features/orders/types";

export const dynamic = "force-dynamic";

const SAMPLE_ORDER = {
  id: "ord-1",
  code: "SY-2026-001234",
  status: "in_progress" as OrderStatus,
  categoryName: { ar: "تكييف وتبريد", en: "HVAC" } as Record<string, string>,
  addressLabel: "حيّ النخيل، شارع الأمير سلطان",
  destination: { lat: 24.7558, lng: 46.6373 },
  providerPing: { lat: 24.7521, lng: 46.6411, at: new Date().toISOString() },
  scheduledAt: null as string | null,
  total: 350,
  estimated: 320,
  providerName: "أحمد الخالدي",
};

export default async function OrderDetailPage({
  params,
}: {
  params: Promise<{ locale: string; id: string }>;
}) {
  const { locale: localeRaw } = await params;
  const locale = localeRaw as Locale;
  setRequestLocale(locale);
  const t = await getTranslations("orders");

  const order = SAMPLE_ORDER;
  // Server components are re-executed per request, so Date.now() is fine here;
  // the purity rule is geared at client components.
  // eslint-disable-next-line react-hooks/purity
  const now = Date.now();
  const timelineEvents = [
    { key: "pending"     as const, at: new Date(now - 1000 * 60 * 90).toISOString() },
    { key: "accepted"    as const, at: new Date(now - 1000 * 60 * 60).toISOString() },
    { key: "en_route"    as const, at: new Date(now - 1000 * 60 * 30).toISOString() },
    { key: "in_progress" as const, at: new Date(now - 1000 * 60 * 10).toISOString() },
  ];

  return (
    <Container className="py-10">
      <nav className="mb-4 text-sm text-text-muted">
        <Link href="/orders" className="hover:text-text">
          {t("title")}
        </Link>
        <span className="mx-2">›</span>
        <span className="text-text">{order.code}</span>
      </nav>

      <header className="mb-6 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-text">
            {order.categoryName[locale] ?? order.categoryName.ar}
          </h1>
          <p className="text-sm text-text-muted">{order.addressLabel}</p>
        </div>
        <OrderStatusBadge status={order.status} />
      </header>

      <div className="grid gap-6 lg:grid-cols-[1fr_360px]">
        <div className="space-y-6">
          <Card>
            <CardHeader><CardTitle>{t("timelineTitle")}</CardTitle></CardHeader>
            <CardBody>
              <OrderTimeline
                status={order.status}
                events={timelineEvents}
                labels={{
                  pending:    t("timeline.pending"),
                  accepted:   t("timeline.accepted"),
                  enRoute:    t("timeline.enRoute"),
                  inProgress: t("timeline.inProgress"),
                  completed:  t("timeline.completed"),
                  cancelled:  t("timeline.cancelled"),
                  rejected:   t("timeline.rejected"),
                  disputed:   t("timeline.disputed"),
                }}
              />
            </CardBody>
          </Card>

          <Card>
            <CardHeader><CardTitle>{t("liveTracking")}</CardTitle></CardHeader>
            <CardBody>
              <TrackingMap destination={order.destination} providerPing={order.providerPing} />
            </CardBody>
          </Card>

          <Card>
            <CardHeader><CardTitle>{t("chatTitle")}</CardTitle></CardHeader>
            <CardBody className="p-0">
              <ChatThread />
            </CardBody>
          </Card>
        </div>

        <aside className="space-y-6">
          <Card>
            <CardHeader><CardTitle>{t("summary")}</CardTitle></CardHeader>
            <CardBody className="space-y-3">
              <Row label={t("orderCode")} value={order.code} mono />
              <Row label={t("provider")} value={order.providerName} />
              <Row
                label={t("estimated")}
                value={`${order.estimated} ${t("currency")}`}
              />
              {order.total != null && (
                <Row
                  label={t("total")}
                  value={`${order.total} ${t("currency")}`}
                />
              )}
            </CardBody>
          </Card>

          <Card>
            <CardHeader><CardTitle>{t("actions")}</CardTitle></CardHeader>
            <CardBody className="flex flex-col gap-2">
              <Button variant="outline">{t("contactProvider")}</Button>
              <Button variant="danger">{t("openDispute")}</Button>
            </CardBody>
          </Card>
        </aside>
      </div>
    </Container>
  );
}

function Row({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <div className="flex flex-col gap-0.5">
      <span className="text-xs text-text-muted">{label}</span>
      <span className={mono ? "font-mono text-sm break-all" : "text-text"}>{value}</span>
    </div>
  );
}
