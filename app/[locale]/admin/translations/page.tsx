import { setRequestLocale, getTranslations } from "next-intl/server";
import { Card, CardHeader, CardTitle, CardBody, Badge } from "@syanah/ui";
import { locales, type Locale } from "@/i18n/locales";
import { flattenMessages, type FlatMessages } from "@/lib/i18n/cms";
import { fetchAllOverrides } from "@/lib/i18n/cms-loader";
import { TranslationsEditor, type EditorRow } from "@/features/admin/components/translations-editor";

export const dynamic = "force-dynamic";

async function loadDefaults(): Promise<Record<Locale, FlatMessages>> {
  const out: Record<Locale, FlatMessages> = {
    ar: {}, ur: {}, en: {}, hi: {}, bn: {},
  };
  await Promise.all(
    locales.map(async (loc) => {
      try {
        const mod = await import(`@/messages/${loc}.json`);
        out[loc] = flattenMessages(mod.default);
      } catch {
        // missing locale file — skip
      }
    }),
  );
  return out;
}

export default async function AdminTranslationsPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("admin.translations");

  const [defaults, overrides] = await Promise.all([
    loadDefaults(),
    fetchAllOverrides(),
  ]);

  const allKeys = new Set<string>();
  for (const loc of locales) {
    for (const k of Object.keys(defaults[loc])) allKeys.add(k);
    for (const k of Object.keys(overrides[loc])) allKeys.add(k);
  }

  const rows: EditorRow[] = Array.from(allKeys)
    .sort()
    .map((key) => {
      const row: EditorRow = {
        key,
        defaults: { ar: "", ur: "", en: "", hi: "", bn: "" },
        overrides: { ar: "", ur: "", en: "", hi: "", bn: "" },
      };
      for (const loc of locales) {
        row.defaults[loc] = defaults[loc][key] ?? "";
        row.overrides[loc] = overrides[loc][key] ?? "";
      }
      return row;
    });

  const overrideCount = locales.reduce(
    (sum, loc) => sum + Object.keys(overrides[loc]).length,
    0,
  );

  return (
    <div className="space-y-6">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-text">{t("title")}</h1>
          <p className="text-text-muted">{t("subtitle")}</p>
        </div>
        <div className="flex flex-col items-end gap-1">
          <Badge tone="primary">{t("totalKeys", { count: rows.length })}</Badge>
          {overrideCount > 0 && (
            <Badge tone="success">{t("overrideCount", { count: overrideCount })}</Badge>
          )}
        </div>
      </header>

      <div className="rounded-md border border-info/30 bg-info/5 p-4 text-sm text-text">
        <p className="font-medium">{t("infoTitle")}</p>
        <p className="mt-1 text-text-muted">{t("infoBody")}</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>{t("editTitle")}</CardTitle>
        </CardHeader>
        <CardBody>
          <TranslationsEditor rows={rows} />
        </CardBody>
      </Card>
    </div>
  );
}
