import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardBody, Badge, Button } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { listCategories, listCities, localized } from "@/lib/catalog/queries";
import { getActiveLocationTree } from "@/lib/catalog/location-tree";
import { CategoryIcon } from "@/components/category-icon";
import { type Locale } from "@/i18n/locales";
import { Search, Star, MapPin, ShieldCheck, Info } from "lucide-react";

export const dynamic = "force-dynamic";

interface Sp {
  q?: string;
  category?: string;
  scope?: "region" | "governorate" | "city" | "district";
  region?: string;
  governorate?: string;
  city?: string;
  district?: string;
}

// Sample providers shown until Supabase has real verified providers. They
// already follow the "registered + verified" rule so the list mirrors the
// production filter.
const SAMPLE_PROVIDERS = [
  {
    id: "p-1",
    name: { ar: "خالد التقني", en: "Khaled Technical" },
    region: "riyadh",
    governorate: "riyadh",
    city: "riyadh",
    district: "النخيل",
    categories: ["hvac", "electrical"],
    rating: 4.9,
    completed: 312,
    isVerified: true,
    tier: "featured",
  },
  {
    id: "p-2",
    name: { ar: "أحمد للسباكة", en: "Ahmed Plumbing" },
    region: "riyadh",
    governorate: "riyadh",
    city: "riyadh",
    district: "العزيزية",
    categories: ["plumbing"],
    rating: 4.7,
    completed: 198,
    isVerified: true,
    tier: "trusted",
  },
  {
    id: "p-3",
    name: { ar: "مؤسسة الجديد", en: "Al-Jadeed Co." },
    region: "makkah",
    governorate: "jeddah",
    city: "jeddah",
    district: "الصفا",
    categories: ["hvac", "appliances"],
    rating: 4.6,
    completed: 145,
    isVerified: true,
    tier: "trusted",
  },
  {
    id: "p-4",
    name: { ar: "خبراء الكهرباء", en: "Electric Experts" },
    region: "eastern",
    governorate: "dammam",
    city: "dammam",
    district: "الفيصلية",
    categories: ["electrical"],
    rating: 4.8,
    completed: 220,
    isVerified: true,
    tier: "featured",
  },
];

export default async function ProvidersPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<Sp>;
}) {
  const { locale: localeRaw } = await params;
  const sp = await searchParams;
  const locale = localeRaw as Locale;
  setRequestLocale(locale);

  const t = await getTranslations("providersList");
  const locT = await getTranslations("location");
  const common = await getTranslations("common");

  const [categories, cities, tree] = await Promise.all([
    listCategories(),
    listCities(),
    getActiveLocationTree(),
  ]);

  // Filter sample providers.
  const filtered = SAMPLE_PROVIDERS.filter((p) => {
    if (sp.category && !p.categories.includes(sp.category)) return false;
    if (sp.region && p.region !== sp.region) return false;
    if (sp.governorate && p.governorate !== sp.governorate) return false;
    if (sp.city && p.city !== sp.city) return false;
    if (sp.district && !p.district.includes(sp.district)) return false;
    if (sp.q) {
      const q = sp.q.toLowerCase();
      const matchesName = Object.values(p.name).some((n) =>
        n.toLowerCase().includes(q),
      );
      if (!matchesName) return false;
    }
    return true;
  });

  const selectedRegion = sp.region ? tree.find((n) => n.region.slug === sp.region) : null;
  const selectedGov =
    selectedRegion && sp.governorate
      ? selectedRegion.governorates.find((g) => g.slug === sp.governorate)
      : null;

  void cities;

  return (
    <Container className="py-10">
      <header className="mb-6 flex flex-col gap-2">
        <h1 className="text-3xl font-bold text-text sm:text-4xl">{t("title")}</h1>
        <p className="text-text-muted">{t("subtitle")}</p>
      </header>

      <div className="mb-4 flex items-center gap-2 rounded-md border border-info/30 bg-info/5 p-3 text-sm text-text">
        <Info className="h-4 w-4 text-info" />
        <span>{t("browsePublicHint")}</span>
      </div>

      {/* Filters — public, no auth required */}
      <form action="" method="get" className="mb-6 space-y-3">
        <div className="flex flex-col gap-3 sm:flex-row">
          <label className="relative flex-1">
            <span className="sr-only">{common("search")}</span>
            <Search
              className="pointer-events-none absolute start-3 top-1/2 h-5 w-5 -translate-y-1/2 text-text-muted"
              aria-hidden
            />
            <input
              type="search"
              name="q"
              defaultValue={sp.q ?? ""}
              placeholder={t("searchPlaceholder")}
              className="h-12 w-full rounded-md border border-border bg-surface ps-10 pe-3 text-text outline-none focus:border-primary"
            />
          </label>
          <select
            name="category"
            defaultValue={sp.category ?? ""}
            className="h-12 rounded-md border border-border bg-surface px-3 text-text outline-none focus:border-primary"
          >
            <option value="">{t("anyCategory")}</option>
            {categories.map((c) => (
              <option key={c.slug} value={c.slug}>
                {localized(c.name, locale)}
              </option>
            ))}
          </select>
        </div>

        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <select
            name="region"
            defaultValue={sp.region ?? ""}
            className="h-11 rounded-md border border-border bg-surface px-3 text-sm text-text outline-none focus:border-primary"
          >
            <option value="">{locT("region")}</option>
            {tree.map((n) => (
              <option key={n.region.slug} value={n.region.slug}>
                {localized(n.region.name, locale)}
              </option>
            ))}
          </select>
          <select
            name="governorate"
            defaultValue={sp.governorate ?? ""}
            disabled={!selectedRegion}
            className="h-11 rounded-md border border-border bg-surface px-3 text-sm text-text outline-none focus:border-primary disabled:opacity-50"
          >
            <option value="">{locT("governorate")}</option>
            {selectedRegion?.governorates.map((g) => (
              <option key={g.slug} value={g.slug}>
                {localized(g.name, locale)}
              </option>
            ))}
          </select>
          <select
            name="city"
            defaultValue={sp.city ?? ""}
            disabled={!selectedGov}
            className="h-11 rounded-md border border-border bg-surface px-3 text-sm text-text outline-none focus:border-primary disabled:opacity-50"
          >
            <option value="">{locT("city")}</option>
            {selectedGov?.cities.map((c) => (
              <option key={c.slug} value={c.slug}>
                {localized(c.name, locale)}
              </option>
            ))}
          </select>
          <input
            type="text"
            name="district"
            defaultValue={sp.district ?? ""}
            placeholder={locT("district")}
            className="h-11 rounded-md border border-border bg-surface px-3 text-sm text-text outline-none focus:border-primary"
          />
        </div>

        <div className="flex justify-end">
          <button
            type="submit"
            className="inline-flex h-11 items-center rounded-md bg-primary px-6 text-sm font-medium text-primary-contrast hover:bg-primary-hover"
          >
            {common("search")}
          </button>
        </div>
      </form>

      {/* Results */}
      {filtered.length === 0 ? (
        <Card>
          <CardBody className="py-12 text-center">
            <p className="text-lg font-semibold text-text">{t("emptyTitle")}</p>
            <p className="mt-2 text-text-muted">{t("emptyBody")}</p>
          </CardBody>
        </Card>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2">
          {filtered.map((p) => (
            <Card key={p.id} className="overflow-hidden">
              <CardBody className="space-y-3">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <div className="flex items-center gap-2">
                      <p className="text-lg font-semibold text-text">
                        {p.name[locale as keyof typeof p.name] ?? p.name.ar}
                      </p>
                      {p.isVerified && (
                        <ShieldCheck
                          className="h-4 w-4 text-success"
                          aria-label="verified"
                        />
                      )}
                    </div>
                    <p className="mt-1 flex items-center gap-1 text-sm text-text-muted">
                      <MapPin className="h-3.5 w-3.5" />
                      {p.district} · {p.city}
                    </p>
                  </div>
                  {p.tier === "featured" && (
                    <Badge tone="primary">{t("featured")}</Badge>
                  )}
                </div>

                <div className="flex flex-wrap items-center gap-2">
                  <span className="inline-flex items-center gap-1 text-sm text-text">
                    <Star className="h-3.5 w-3.5 fill-warning text-warning" />
                    {p.rating}
                  </span>
                  <span className="text-xs text-text-muted">
                    · {t("completedShort", { count: p.completed })}
                  </span>
                </div>

                <div className="flex flex-wrap gap-1.5">
                  {p.categories.map((slug) => {
                    const cat = categories.find((c) => c.slug === slug);
                    return (
                      <Badge key={slug} tone="neutral">
                        {cat ? localized(cat.name, locale) : slug}
                      </Badge>
                    );
                  })}
                </div>

                <div className="flex gap-2 pt-1">
                  <Link href={`/providers/${p.id}`} className="flex-1">
                    <Button size="sm" variant="outline" fullWidth>
                      {t("view")}
                    </Button>
                  </Link>
                  <Link href="/sign-up" className="flex-1">
                    <Button size="sm" fullWidth>
                      {t("orderRequiresSignup")}
                    </Button>
                  </Link>
                </div>
              </CardBody>
            </Card>
          ))}
        </div>
      )}
    </Container>
  );
}
