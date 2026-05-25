import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardBody, Button } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { Plus, Heart, Trash2 } from "lucide-react";
import { type Locale } from "@/i18n/locales";

export const dynamic = "force-dynamic";

const SAMPLE = [
  { slug: "hvac-clean", name: { ar: "تنظيف مكيّفات", en: "AC cleaning" },     note: "كل ٦ أشهر" },
  { slug: "leak-fix",   name: { ar: "إصلاح تسرّب",   en: "Leak repair" },     note: "" },
  { slug: "oil-change", name: { ar: "تغيير زيت",     en: "Oil change" },      note: "ﻟﻠﺴﻴﺎﺭﺓ ﺍﻟﺒﻴﻀﺎﺀ" },
  { slug: "pest-spray", name: { ar: "رش حشرات",      en: "Pest control" },    note: "" },
];

export default async function SavedServicesPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("dashboard.saved");

  return (
    <Container className="py-10">
      <header className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-text">{t("title")}</h1>
          <p className="text-sm text-text-muted">{t("subtitle")}</p>
        </div>
        <Link href="/services">
          <Button iconStart={<Plus className="h-4 w-4" />}>{t("addCta")}</Button>
        </Link>
      </header>

      {SAMPLE.length === 0 ? (
        <Card>
          <CardBody className="py-12 text-center">
            <Heart className="mx-auto mb-3 h-8 w-8 text-text-muted" />
            <p className="text-text">{t("empty")}</p>
            <Link href="/services">
              <Button className="mt-4">{t("browse")}</Button>
            </Link>
          </CardBody>
        </Card>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2">
          {SAMPLE.map((s) => (
            <Card key={s.slug}>
              <CardBody>
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <p className="font-medium text-text">
                      {(s.name as Record<string, string>)[locale] ?? s.name.ar}
                    </p>
                    {s.note && (
                      <p className="mt-1 text-xs text-text-muted">{s.note}</p>
                    )}
                  </div>
                  <button
                    type="button"
                    aria-label={t("remove")}
                    className="text-text-muted hover:text-danger"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
                <div className="mt-3 flex gap-2">
                  <Link href="/orders/new" className="flex-1">
                    <Button size="sm" fullWidth>{t("orderNow")}</Button>
                  </Link>
                  <Button size="sm" variant="outline">{t("editNote")}</Button>
                </div>
              </CardBody>
            </Card>
          ))}
        </div>
      )}
    </Container>
  );
}
