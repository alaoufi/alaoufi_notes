import { getTranslations } from "next-intl/server";
import { Card, CardHeader, CardTitle, CardBody, Button, Badge } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { Plus, Heart, Clock, MapPin, ChevronRight } from "lucide-react";

interface SavedService {
  slug: string;
  name: Record<string, string>;
}

interface RecentOrder {
  id: string;
  code: string;
  category: string;
  status: "pending" | "in_progress" | "completed";
  at: string;
}

const SAMPLE_SAVED: SavedService[] = [
  { slug: "hvac-clean", name: { ar: "تنظيف مكيّفات", en: "AC cleaning" } },
  { slug: "leak-fix",   name: { ar: "إصلاح تسرّب",     en: "Leak repair" } },
  { slug: "oil-change", name: { ar: "تغيير زيت",       en: "Oil change" } },
];

const SAMPLE_RECENT: RecentOrder[] = [
  { id: "ord-1", code: "SY-2026-001234", category: "تكييف",  status: "in_progress", at: "منذ ساعة" },
  { id: "ord-2", code: "SY-2026-001190", category: "سباكة",  status: "completed",   at: "منذ ٣ أيام" },
];

export async function RequesterDashboard({ locale }: { locale: string }) {
  const t = await getTranslations("dashboard.requester");
  const ordersT = await getTranslations("orders.status");

  return (
    <div className="space-y-6">
      {/* Quick actions */}
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Link href="/orders/new" className="block">
          <Card className="h-full transition-shadow hover:shadow-md">
            <CardBody className="flex items-center gap-3">
              <span className="grid h-11 w-11 place-items-center rounded-md bg-primary text-primary-contrast">
                <Plus className="h-5 w-5" />
              </span>
              <div>
                <p className="text-sm font-semibold text-text">{t("quick.newOrder")}</p>
                <p className="text-xs text-text-muted">{t("quick.newOrderHint")}</p>
              </div>
            </CardBody>
          </Card>
        </Link>
        <Link href="/dashboard/saved" className="block">
          <Card className="h-full transition-shadow hover:shadow-md">
            <CardBody className="flex items-center gap-3">
              <span className="grid h-11 w-11 place-items-center rounded-md bg-accent/10 text-accent">
                <Heart className="h-5 w-5" />
              </span>
              <div>
                <p className="text-sm font-semibold text-text">{t("quick.saved")}</p>
                <p className="text-xs text-text-muted">{t("quick.savedHint", { count: SAMPLE_SAVED.length })}</p>
              </div>
            </CardBody>
          </Card>
        </Link>
        <Link href="/orders" className="block">
          <Card className="h-full transition-shadow hover:shadow-md">
            <CardBody className="flex items-center gap-3">
              <span className="grid h-11 w-11 place-items-center rounded-md bg-info/10 text-info">
                <Clock className="h-5 w-5" />
              </span>
              <div>
                <p className="text-sm font-semibold text-text">{t("quick.orders")}</p>
                <p className="text-xs text-text-muted">{t("quick.ordersHint")}</p>
              </div>
            </CardBody>
          </Card>
        </Link>
        <Link href="/profile" className="block">
          <Card className="h-full transition-shadow hover:shadow-md">
            <CardBody className="flex items-center gap-3">
              <span className="grid h-11 w-11 place-items-center rounded-md bg-success/10 text-success">
                <MapPin className="h-5 w-5" />
              </span>
              <div>
                <p className="text-sm font-semibold text-text">{t("quick.profile")}</p>
                <p className="text-xs text-text-muted">{t("quick.profileHint")}</p>
              </div>
            </CardBody>
          </Card>
        </Link>
      </div>

      {/* Saved services */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>{t("savedTitle")}</CardTitle>
            <Link href="/dashboard/saved" className="text-sm text-primary hover:underline">
              {t("seeAll")}
            </Link>
          </div>
        </CardHeader>
        <CardBody>
          {SAMPLE_SAVED.length === 0 ? (
            <p className="text-sm text-text-muted">{t("savedEmpty")}</p>
          ) : (
            <ul className="divide-y divide-border">
              {SAMPLE_SAVED.map((s) => (
                <li key={s.slug} className="flex items-center justify-between py-3">
                  <span className="text-text">{s.name[locale] ?? s.name.ar}</span>
                  <Link href="/orders/new">
                    <Button size="sm" variant="outline">{t("orderNow")}</Button>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </CardBody>
      </Card>

      {/* Recent activity */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>{t("recentTitle")}</CardTitle>
            <Link href="/orders" className="text-sm text-primary hover:underline">
              {t("seeAll")}
            </Link>
          </div>
        </CardHeader>
        <CardBody>
          {SAMPLE_RECENT.length === 0 ? (
            <p className="text-sm text-text-muted">{t("recentEmpty")}</p>
          ) : (
            <ul className="divide-y divide-border">
              {SAMPLE_RECENT.map((o) => (
                <li key={o.id} className="flex items-center justify-between py-3">
                  <Link href={`/orders/${o.id}`} className="flex-1">
                    <p className="font-mono text-xs text-text-muted">{o.code}</p>
                    <p className="text-text">{o.category}</p>
                    <p className="text-xs text-text-muted">{o.at}</p>
                  </Link>
                  <div className="flex items-center gap-2">
                    <Badge
                      tone={
                        o.status === "completed"
                          ? "success"
                          : o.status === "in_progress"
                            ? "primary"
                            : "warning"
                      }
                    >
                      {ordersT(o.status)}
                    </Badge>
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
