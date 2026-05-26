import { setRequestLocale, getTranslations } from "next-intl/server";
import { Card, CardBody, Button } from "@syanah/ui";
import { listCategories, localized } from "@/lib/catalog/queries";
import { CategoryIcon } from "@/components/category-icon";
import { type Locale } from "@/i18n/locales";
import { Plus } from "lucide-react";
import { requireAdminSection } from "@/lib/auth/sections";
import { hasSupabaseEnv } from "@/lib/supabase/env";

export const dynamic = "force-dynamic";

export default async function AdminCategoriesPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale: localeRaw } = await params;
  const locale = localeRaw as Locale;
  setRequestLocale(locale);
  if (hasSupabaseEnv()) await requireAdminSection("categories");
  const t = await getTranslations("admin.categories");
  const cats = await listCategories();

  return (
    <div className="space-y-6">
      <header className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-text">{t("title")}</h1>
          <p className="text-text-muted">{t("subtitle")}</p>
        </div>
        <Button iconStart={<Plus className="h-4 w-4" />}>{t("addCta")}</Button>
      </header>

      <Card>
        <CardBody>
          <div className="divide-y divide-border">
            {cats.map((c) => (
              <div key={c.slug} className="flex items-center justify-between py-3">
                <div className="flex items-center gap-3">
                  <span className="grid h-9 w-9 place-items-center rounded-md bg-primary/10 text-primary">
                    <CategoryIcon iconKey={c.icon_key} />
                  </span>
                  <div>
                    <p className="font-medium text-text">{localized(c.name, locale)}</p>
                    <p className="font-mono text-xs text-text-muted">{c.slug}</p>
                  </div>
                </div>
                <Button size="sm" variant="outline">{t("edit")}</Button>
              </div>
            ))}
          </div>
        </CardBody>
      </Card>
    </div>
  );
}
