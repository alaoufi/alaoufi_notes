import { getTranslations } from "next-intl/server";
import { Card, CardHeader, CardTitle, CardBody, Button, Badge } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { Inbox, Users, Star, Wallet, ChevronRight, CheckCircle2 } from "lucide-react";

interface Customer {
  id: string;
  name: string;
  ordersCount: number;
  lastOrderAt: string;
}

interface IncomingOrder {
  id: string;
  code: string;
  category: string;
  city: string;
  scheduled: string;
}

const SAMPLE_CUSTOMERS: Customer[] = [
  { id: "c-1", name: "نورة الزهراني", ordersCount: 4, lastOrderAt: "منذ ٤ أيام" },
  { id: "c-2", name: "محمد القحطاني", ordersCount: 2, lastOrderAt: "منذ أسبوع" },
  { id: "c-3", name: "فاطمة العتيبي", ordersCount: 1, lastOrderAt: "منذ شهر" },
];

const SAMPLE_INCOMING: IncomingOrder[] = [
  { id: "ord-7", code: "SY-2026-001302", category: "تكييف",  city: "الرياض", scheduled: "خلال ٢٠ دقيقة" },
  { id: "ord-8", code: "SY-2026-001305", category: "كهرباء", city: "الخرج",  scheduled: "اليوم ٥ مساءً" },
];

export async function ProviderDashboard({ locale }: { locale: string }) {
  void locale;
  const t = await getTranslations("dashboard.provider");

  return (
    <div className="space-y-6">
      {/* KPIs */}
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardBody className="flex items-center gap-3">
            <span className="grid h-11 w-11 place-items-center rounded-md bg-primary/10 text-primary">
              <Inbox className="h-5 w-5" />
            </span>
            <div>
              <p className="text-xs text-text-muted">{t("kpi.incoming")}</p>
              <p className="text-xl font-bold text-text">{SAMPLE_INCOMING.length}</p>
            </div>
          </CardBody>
        </Card>
        <Card>
          <CardBody className="flex items-center gap-3">
            <span className="grid h-11 w-11 place-items-center rounded-md bg-success/10 text-success">
              <CheckCircle2 className="h-5 w-5" />
            </span>
            <div>
              <p className="text-xs text-text-muted">{t("kpi.completed30d")}</p>
              <p className="text-xl font-bold text-text">23</p>
            </div>
          </CardBody>
        </Card>
        <Card>
          <CardBody className="flex items-center gap-3">
            <span className="grid h-11 w-11 place-items-center rounded-md bg-warning/10 text-warning">
              <Star className="h-5 w-5" />
            </span>
            <div>
              <p className="text-xs text-text-muted">{t("kpi.rating")}</p>
              <p className="text-xl font-bold text-text">4.8</p>
            </div>
          </CardBody>
        </Card>
        <Card>
          <CardBody className="flex items-center gap-3">
            <span className="grid h-11 w-11 place-items-center rounded-md bg-accent/10 text-accent">
              <Wallet className="h-5 w-5" />
            </span>
            <div>
              <p className="text-xs text-text-muted">{t("kpi.earnings30d")}</p>
              <p className="text-xl font-bold text-text">8,420 ر.س</p>
            </div>
          </CardBody>
        </Card>
      </div>

      {/* Incoming orders */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>{t("incomingTitle")}</CardTitle>
            <Link href="/orders" className="text-sm text-primary hover:underline">
              {t("seeAll")}
            </Link>
          </div>
        </CardHeader>
        <CardBody>
          {SAMPLE_INCOMING.length === 0 ? (
            <p className="text-sm text-text-muted">{t("incomingEmpty")}</p>
          ) : (
            <ul className="divide-y divide-border">
              {SAMPLE_INCOMING.map((o) => (
                <li key={o.id} className="flex items-center justify-between gap-3 py-3">
                  <Link href={`/orders/${o.id}`} className="flex-1">
                    <p className="font-mono text-xs text-text-muted">{o.code}</p>
                    <p className="text-text">{o.category} · {o.city}</p>
                    <p className="text-xs text-text-muted">{o.scheduled}</p>
                  </Link>
                  <div className="flex items-center gap-2">
                    <Button size="sm" variant="outline">{t("decline")}</Button>
                    <Button size="sm">{t("accept")}</Button>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </CardBody>
      </Card>

      {/* Customers */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle className="flex items-center gap-2">
              <Users className="h-4 w-4 text-text-muted" />
              {t("customersTitle")}
            </CardTitle>
            <Link href="/dashboard/customers" className="text-sm text-primary hover:underline">
              {t("seeAll")}
            </Link>
          </div>
        </CardHeader>
        <CardBody>
          {SAMPLE_CUSTOMERS.length === 0 ? (
            <p className="text-sm text-text-muted">{t("customersEmpty")}</p>
          ) : (
            <ul className="divide-y divide-border">
              {SAMPLE_CUSTOMERS.map((c) => (
                <li key={c.id} className="flex items-center justify-between py-3">
                  <Link href={`/dashboard/customers/${c.id}`} className="flex-1">
                    <p className="font-medium text-text">{c.name}</p>
                    <p className="text-xs text-text-muted">{c.lastOrderAt}</p>
                  </Link>
                  <div className="flex items-center gap-2">
                    <Badge tone="primary">{t("ordersCount", { count: c.ordersCount })}</Badge>
                    <ChevronRight className="h-4 w-4 text-text-muted rtl:rotate-180" />
                  </div>
                </li>
              ))}
            </ul>
          )}
        </CardBody>
      </Card>
    </div>
  );
}
