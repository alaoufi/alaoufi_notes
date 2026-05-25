import { getTranslations } from "next-intl/server";
import { Container } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { listCategories, localized } from "@/lib/catalog/queries";
import { CategoryIcon } from "@/components/category-icon";
import { ArrowRight } from "lucide-react";
import type { Locale } from "@/i18n/locales";

const TONES: Record<string, { ring: string; glow: string }> = {
  hvac:       { ring: "ring-info/20",    glow: "from-info/15 to-info/0" },
  plumbing:   { ring: "ring-success/20", glow: "from-success/15 to-success/0" },
  electrical: { ring: "ring-warning/20", glow: "from-warning/15 to-warning/0" },
  appliances: { ring: "ring-primary/20", glow: "from-primary/15 to-primary/0" },
  home:       { ring: "ring-accent/20",  glow: "from-accent/15 to-accent/0" },
  vehicle:    { ring: "ring-info/20",    glow: "from-info/15 to-info/0" },
  cleaning:   { ring: "ring-accent/20",  glow: "from-accent/15 to-accent/0" },
  pest:       { ring: "ring-danger/20",  glow: "from-danger/15 to-danger/0" },
};

const DEFAULT_TONE = { ring: "ring-primary/20", glow: "from-primary/15 to-primary/0" };

export async function Categories({ locale }: { locale: Locale }) {
  const t = await getTranslations("categories");
  const categories = await listCategories();

  return (
    <section className="py-20">
      <Container>
        <div className="mx-auto mb-12 flex max-w-2xl flex-col items-center gap-3 text-center">
          <span className="text-xs font-semibold uppercase tracking-[0.2em] text-primary">
            {t("eyebrow")}
          </span>
          <h2 className="text-3xl font-bold text-text sm:text-4xl">{t("title")}</h2>
          <p className="text-text-muted">{t("subtitle")}</p>
        </div>

        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4">
          {categories.map((cat) => {
            const tone = TONES[cat.slug] ?? DEFAULT_TONE;
            return (
              <Link
                key={cat.slug}
                href={`/services/${cat.slug}`}
                className="group relative isolate flex flex-col gap-4 overflow-hidden rounded-xl border border-border bg-surface p-5 transition-all hover:-translate-y-1 hover:shadow-md focus:outline-none"
              >
                <span
                  className={`pointer-events-none absolute -end-12 -top-12 h-32 w-32 rounded-full bg-gradient-to-br ${tone.glow} opacity-0 transition-opacity group-hover:opacity-100`}
                  aria-hidden
                />
                <span
                  className={`grid h-12 w-12 place-items-center rounded-lg bg-primary/10 text-primary ring-1 ${tone.ring} transition-transform group-hover:scale-110`}
                >
                  <CategoryIcon iconKey={cat.icon_key} className="h-6 w-6" />
                </span>
                <div className="flex-1">
                  <h3 className="text-base font-semibold text-text">
                    {localized(cat.name, locale)}
                  </h3>
                </div>
                <div className="inline-flex items-center gap-1 text-sm text-text-muted opacity-0 transition-opacity group-hover:opacity-100">
                  <span>{t("browse")}</span>
                  <ArrowRight className="h-3.5 w-3.5 rtl:rotate-180" />
                </div>
              </Link>
            );
          })}
        </div>
      </Container>
    </section>
  );
}
