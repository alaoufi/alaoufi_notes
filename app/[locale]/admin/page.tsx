import { setRequestLocale, getTranslations } from "next-intl/server";
import { Card, CardHeader, CardTitle, CardBody, Badge } from "@syanah/ui";
import { type Locale } from "@/i18n/locales";
import { MiniAreaChart, MiniBarChart } from "@/features/admin/components/charts";
import { ClipboardList, Users, AlertTriangle, DollarSign, Star, Tag, ArrowUpRight, ArrowDownRight } from "lucide-react";

export const dynamic = "force-dynamic";

const KPIS = [
  { key: "ordersToday",     value: "47",          trend: "+18%", icon: ClipboardList, tone: "primary" as const },
  { key: "activeProviders", value: "312",         trend: "+5%",  icon: Users,         tone: "success" as const },
  { key: "openDisputes",    value: "4",           trend: "-2",   icon: AlertTriangle, tone: "warning" as const },
  { key: "monthlyRevenue",  value: "62,400 ر.س",  trend: "+11%", icon: DollarSign,    tone: "accent"  as const },
];

// Demo time-series. When we wire up Supabase aggregates we'll pull these
// from a server query.
const ORDERS_TREND = [
  { label: "أحد", value: 22 },
  { label: "اثن", value: 31 },
  { label: "ثلا", value: 28 },
  { label: "أرب", value: 40 },
  { label: "خمي", value: 36 },
  { label: "جمع", value: 47 },
  { label: "سبت", value: 39 },
];

const TOP_CATEGORIES = [
  { label: "تكييف",    value: 84 },
  { label: "سباكة",    value: 61 },
  { label: "كهرباء",   value: 53 },
  { label: "تنظيف",    value: 38 },
  { label: "سيارات",   value: 27 },
];

const TOP_PROVIDERS = [
  { name: "خالد التقني",  rating: 4.9, completed: 312, city: "الرياض" },
  { name: "أحمد للسباكة", rating: 4.8, completed: 198, city: "الرياض" },
  { name: "نورة كهرباء",  rating: 4.8, completed: 154, city: "جدة" },
];

const RECENT_ORDERS = [
  { code: "SY-2026-001247", customer: "محمد القحطاني", category: "تكييف",  status: "in_progress" },
  { code: "SY-2026-001246", customer: "نورة الزهراني", category: "سباكة",  status: "pending"      },
  { code: "SY-2026-001245", customer: "أحمد العتيبي",  category: "كهرباء", status: "completed"    },
  { code: "SY-2026-001244", customer: "سارة الشهري",   category: "تكييف",  status: "completed"    },
];

const STATUS_TONE: Record<string, "primary" | "success" | "warning"> = {
  pending: "warning",
  in_progress: "primary",
  completed: "success",
};

export default async function AdminOverviewPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("admin.overview");
  const tOrders = await getTranslations("orders.status");

  return (
    <div className="space-y-6">
      <header className="flex flex-col gap-1">
        <h1 className="text-2xl font-bold text-text">{t("title")}</h1>
        <p className="text-text-muted">{t("subtitle")}</p>
        <p className="mt-1 text-xs text-text-muted">{t("demoNote")}</p>
      </header>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {KPIS.map((k) => {
          const down = k.trend.startsWith("-");
          const TrendIcon = down ? ArrowDownRight : ArrowUpRight;
          return (
            <Card key={k.key}>
              <CardBody className="space-y-2">
                <div className="flex items-center justify-between">
                  <span
                    className={`grid h-9 w-9 place-items-center rounded-md ${
                      k.tone === "primary" ? "bg-primary/10 text-primary" :
                      k.tone === "success" ? "bg-success/10 text-success" :
                      k.tone === "warning" ? "bg-warning/10 text-warning" :
                                             "bg-accent/10 text-accent"
                    }`}
                  >
                    <k.icon className="h-4 w-4" />
                  </span>
                  <Badge tone={down ? "danger" : "success"} className="inline-flex items-center gap-0.5">
                    <TrendIcon className="h-3 w-3" />
                    {k.trend.replace("-", "").replace("+", "")}
                  </Badge>
                </div>
                <p className="text-xs text-text-muted">{t(`kpi.${k.key}`)}</p>
                <p className="text-2xl font-bold text-text">{k.value}</p>
              </CardBody>
            </Card>
          );
        })}
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>{t("charts.ordersWeek")}</CardTitle>
          </CardHeader>
          <CardBody>
            <MiniAreaChart data={ORDERS_TREND} ariaLabel={t("charts.ordersWeek")} />
          </CardBody>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>{t("charts.topCategories")}</CardTitle>
          </CardHeader>
          <CardBody>
            <MiniBarChart data={TOP_CATEGORIES} ariaLabel={t("charts.topCategories")} />
          </CardBody>
        </Card>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Star className="h-4 w-4 text-warning" />
              {t("topProviders")}
            </CardTitle>
          </CardHeader>
          <CardBody>
            <ul className="divide-y divide-border">
              {TOP_PROVIDERS.map((p, i) => (
                <li key={i} className="flex items-center justify-between py-2.5">
                  <div className="flex items-center gap-3">
                    <span className="grid h-8 w-8 place-items-center rounded-pill bg-primary/10 font-bold text-primary">
                      {i + 1}
                    </span>
                    <div>
                      <p className="text-sm font-medium text-text">{p.name}</p>
                      <p className="text-xs text-text-muted">{p.city}</p>
                    </div>
                  </div>
                  <div className="text-end">
                    <p className="inline-flex items-center gap-1 text-sm font-semibold">
                      <Star className="h-3.5 w-3.5 fill-warning text-warning" />
                      {p.rating}
                    </p>
                    <p className="text-xs text-text-muted">{p.completed} طلب</p>
                  </div>
                </li>
              ))}
            </ul>
          </CardBody>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Tag className="h-4 w-4 text-primary" />
              {t("recentOrders")}
            </CardTitle>
          </CardHeader>
          <CardBody>
            <ul className="divide-y divide-border">
              {RECENT_ORDERS.map((o) => (
                <li key={o.code} className="flex items-center justify-between py-2.5">
                  <div>
                    <p className="font-mono text-xs text-text-muted">{o.code}</p>
                    <p className="text-sm font-medium text-text">
                      {o.customer} · {o.category}
                    </p>
                  </div>
                  <Badge tone={STATUS_TONE[o.status] ?? "neutral"}>
                    {tOrders(o.status)}
                  </Badge>
                </li>
              ))}
            </ul>
          </CardBody>
        </Card>
      </div>
    </div>
  );
}
