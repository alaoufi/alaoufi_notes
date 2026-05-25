import { setRequestLocale, getTranslations } from "next-intl/server";
import { Card, CardHeader, CardTitle, CardBody, Input, Button } from "@syanah/ui";
import { type Locale } from "@/i18n/locales";
import { locales, localeNames } from "@/i18n/locales";

export const dynamic = "force-dynamic";

// Demo entries (real ones come from the `translations` table).
const SAMPLE_KEYS = [
  "brand.name",
  "brand.tagline",
  "home.heroTitle",
  "home.ctaPrimary",
  "nav.signIn",
];

export default async function AdminTranslationsPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale: localeRaw } = await params;
  const locale = localeRaw as Locale;
  setRequestLocale(locale);
  const t = await getTranslations("admin.translations");

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold text-text">{t("title")}</h1>
        <p className="text-text-muted">{t("subtitle")}</p>
      </header>

      <Card>
        <CardHeader>
          <CardTitle>{t("editTitle")}</CardTitle>
        </CardHeader>
        <CardBody className="space-y-4">
          <Input label={t("searchLabel")} placeholder={t("searchPlaceholder")} />
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-text-muted">
                  <th className="px-2 py-2 text-start">{t("keyHeader")}</th>
                  {locales.map((loc) => (
                    <th key={loc} className="px-2 py-2 text-start">
                      {localeNames[loc]}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {SAMPLE_KEYS.map((key) => (
                  <tr key={key} className="border-t border-border">
                    <td className="px-2 py-2 font-mono text-xs">{key}</td>
                    {locales.map((loc) => (
                      <td key={loc} className="px-2 py-2">
                        <input
                          defaultValue=""
                          placeholder={t("placeholder")}
                          className="h-9 w-full rounded-md border border-border bg-surface px-2 outline-none focus:border-primary"
                        />
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="flex justify-end">
            <Button>{t("save")}</Button>
          </div>
        </CardBody>
      </Card>
    </div>
  );
}
