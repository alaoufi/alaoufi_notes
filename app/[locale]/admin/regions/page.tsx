import { setRequestLocale, getTranslations } from "next-intl/server";
import { Card, CardBody, Badge } from "@syanah/ui";
import { listAllRegions, listGovernorates, localized } from "@/lib/catalog/queries";
import { RegionToggle, GovernorateToggle } from "@/features/admin/components/region-toggle";
import { type Locale } from "@/i18n/locales";

export const dynamic = "force-dynamic";

export default async function AdminRegionsPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale: localeRaw } = await params;
  const locale = localeRaw as Locale;
  setRequestLocale(locale);
  const t = await getTranslations("admin.regions");

  const regions = await listAllRegions();
  const governoratesByRegion = await Promise.all(
    regions.map(async (r) => ({ region: r, governorates: await listGovernorates(r.slug) })),
  );

  const activeCount = regions.filter((r) => r.is_active).length;

  return (
    <div className="space-y-6">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-text">{t("title")}</h1>
          <p className="text-text-muted">{t("subtitle")}</p>
        </div>
        <div className="flex items-center gap-2">
          <Badge tone="primary">{t("activeCount", { count: activeCount, total: regions.length })}</Badge>
        </div>
      </header>

      <div className="rounded-md border border-info/30 bg-info/5 p-4 text-sm text-text">
        <p className="font-medium">{t("infoTitle")}</p>
        <p className="mt-1 text-text-muted">{t("infoBody")}</p>
      </div>

      <div className="space-y-4">
        {governoratesByRegion.map(({ region, governorates }) => (
          <Card key={region.slug}>
            <CardBody className="space-y-4">
              {/* region row */}
              <div className="flex items-center justify-between gap-4">
                <div>
                  <h2 className="text-lg font-semibold text-text">
                    {localized(region.name, locale)}
                  </h2>
                  <p className="font-mono text-xs text-text-muted">{region.slug}</p>
                </div>
                <div className="flex items-center gap-3">
                  <Badge tone={region.is_active ? "success" : "neutral"}>
                    {region.is_active ? t("status.active") : t("status.inactive")}
                  </Badge>
                  <RegionToggle id={region.id} initialActive={region.is_active} />
                </div>
              </div>

              {/* governorates */}
              {governorates.length > 0 && (
                <div className="border-t border-border pt-3">
                  <p className="mb-2 text-xs font-semibold uppercase tracking-wider text-text-muted">
                    {t("governorates")} ({governorates.length})
                  </p>
                  <div className="divide-y divide-border">
                    {governorates.map((gov) => (
                      <div key={gov.slug} className="flex items-center justify-between gap-3 py-2">
                        <div>
                          <p className="font-medium text-text">
                            {localized(gov.name, locale)}
                          </p>
                          <p className="font-mono text-[11px] text-text-muted">{gov.slug}</p>
                        </div>
                        <div className="flex items-center gap-2">
                          <Badge tone={gov.is_active ? "success" : "neutral"}>
                            {gov.is_active ? t("status.active") : t("status.inactive")}
                          </Badge>
                          <GovernorateToggle
                            id={gov.id}
                            initialActive={gov.is_active}
                            disabled={!region.is_active}
                          />
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {governorates.length === 0 && (
                <p className="border-t border-border pt-3 text-sm text-text-muted">
                  {t("noGovernorates")}
                </p>
              )}
            </CardBody>
          </Card>
        ))}
      </div>
    </div>
  );
}
