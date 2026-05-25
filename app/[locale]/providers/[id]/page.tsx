import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardHeader, CardTitle, CardBody, Button, Badge } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { Star, MapPin, ShieldCheck, Phone, Calendar, Award, ArrowLeft } from "lucide-react";
import { type Locale } from "@/i18n/locales";

export const dynamic = "force-dynamic";

const SAMPLE = {
  "p-1": {
    name: { ar: "خالد التقني", en: "Khaled Technical" },
    city: "الرياض · النخيل",
    bio: { ar: "خبرة 12 سنة في صيانة التكييف والكهرباء. متاح طوال أيام الأسبوع.", en: "12 years of HVAC and electrical experience. Available all week." },
    rating: 4.9,
    completed: 312,
    isVerified: true,
    tier: "featured" as const,
    categories: ["تكييف", "كهرباء"],
    sinceYear: 2014,
  },
  "p-2": {
    name: { ar: "أحمد للسباكة", en: "Ahmed Plumbing" },
    city: "الرياض · العزيزية",
    bio: { ar: "متخصّص في إصلاح التسرّبات وتسليك الصرف.", en: "Specialized in leak repair and drain unclogging." },
    rating: 4.7,
    completed: 198,
    isVerified: true,
    tier: "trusted" as const,
    categories: ["سباكة"],
    sinceYear: 2018,
  },
} as const;

export default async function ProviderDetailPage({
  params,
}: {
  params: Promise<{ locale: string; id: string }>;
}) {
  const { locale: localeRaw, id } = await params;
  const locale = localeRaw as Locale;
  setRequestLocale(locale);
  const t = await getTranslations("providerDetail");
  const list = await getTranslations("providersList");

  const provider = (SAMPLE as Record<string, (typeof SAMPLE)[keyof typeof SAMPLE]>)[id];

  if (!provider) {
    return (
      <Container className="py-16">
        <Card>
          <CardBody className="py-16 text-center">
            <p className="text-text">{t("notFound")}</p>
            <Link href="/providers" className="mt-4 inline-block">
              <Button variant="outline" iconStart={<ArrowLeft className="h-4 w-4 rtl:rotate-180" />}>
                {t("backToList")}
              </Button>
            </Link>
          </CardBody>
        </Card>
      </Container>
    );
  }

  return (
    <Container className="py-10">
      <nav className="mb-4 text-sm text-text-muted">
        <Link href="/providers" className="hover:text-text">
          {list("title")}
        </Link>
        <span className="mx-2">›</span>
        <span className="text-text">
          {provider.name[locale as keyof typeof provider.name] ?? provider.name.ar}
        </span>
      </nav>

      <div className="grid gap-6 lg:grid-cols-[1fr_320px]">
        <div className="space-y-6">
          <Card>
            <CardBody className="space-y-4">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <div className="flex items-center gap-2">
                    <h1 className="text-2xl font-bold text-text">
                      {provider.name[locale as keyof typeof provider.name] ?? provider.name.ar}
                    </h1>
                    {provider.isVerified && (
                      <ShieldCheck className="h-5 w-5 text-success" />
                    )}
                  </div>
                  <p className="mt-1 flex items-center gap-1 text-sm text-text-muted">
                    <MapPin className="h-4 w-4" />
                    {provider.city}
                  </p>
                </div>
                {provider.tier === "featured" && (
                  <Badge tone="primary">{list("featured")}</Badge>
                )}
              </div>

              <div className="flex flex-wrap items-center gap-4">
                <span className="inline-flex items-center gap-1 text-base text-text">
                  <Star className="h-4 w-4 fill-warning text-warning" />
                  <span className="font-semibold">{provider.rating}</span>
                </span>
                <span className="text-sm text-text-muted">
                  {list("completedShort", { count: provider.completed })}
                </span>
                <span className="text-sm text-text-muted">
                  <Calendar className="me-1 inline h-3.5 w-3.5" />
                  {t("memberSince", { year: provider.sinceYear })}
                </span>
              </div>

              <p className="leading-relaxed text-text">
                {provider.bio[locale as keyof typeof provider.bio] ?? provider.bio.ar}
              </p>

              <div className="flex flex-wrap gap-2 border-t border-border pt-4">
                {provider.categories.map((c) => (
                  <Badge key={c} tone="neutral">{c}</Badge>
                ))}
              </div>
            </CardBody>
          </Card>

          <Card>
            <CardHeader><CardTitle>{t("recentReviews")}</CardTitle></CardHeader>
            <CardBody className="space-y-3">
              {[
                { name: "نورة الزهراني", rating: 5, body: "خدمة سريعة ونظيفة. أنصح بالتعامل معه." },
                { name: "محمد القحطاني", rating: 5, body: "وصل في الموعد بالضبط، احترافي جداً." },
              ].map((rev, i) => (
                <div key={i} className="border-b border-border pb-3 last:border-b-0 last:pb-0">
                  <div className="flex items-center gap-2">
                    <p className="font-medium text-text">{rev.name}</p>
                    <div className="flex">
                      {Array.from({ length: rev.rating }).map((_, idx) => (
                        <Star key={idx} className="h-3.5 w-3.5 fill-warning text-warning" />
                      ))}
                    </div>
                  </div>
                  <p className="mt-1 text-sm text-text-muted">{rev.body}</p>
                </div>
              ))}
            </CardBody>
          </Card>
        </div>

        <aside className="space-y-4">
          <Card>
            <CardBody className="space-y-3">
              <Link href="/sign-up" className="block">
                <Button fullWidth size="lg">{list("orderRequiresSignup")}</Button>
              </Link>
              <Button variant="outline" fullWidth iconStart={<Phone className="h-4 w-4" />}>
                {t("contactProvider")}
              </Button>
            </CardBody>
          </Card>

          <Card>
            <CardHeader><CardTitle>{t("trust")}</CardTitle></CardHeader>
            <CardBody className="space-y-2 text-sm">
              <p className="flex items-center gap-2 text-text">
                <ShieldCheck className="h-4 w-4 text-success" />
                {t("identityVerified")}
              </p>
              <p className="flex items-center gap-2 text-text">
                <Award className="h-4 w-4 text-primary" />
                {t("guaranteed")}
              </p>
            </CardBody>
          </Card>
        </aside>
      </div>
    </Container>
  );
}
