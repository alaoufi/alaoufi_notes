import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardHeader, CardTitle, CardBody, Button, Badge } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { Check } from "lucide-react";
import { type Locale } from "@/i18n/locales";

interface Tier {
  slug: "free" | "trusted" | "featured";
  monthlyPrice: number;
  commissionPct: number;
  featured?: boolean;
  features: number;
}

const TIERS: Tier[] = [
  { slug: "free", monthlyPrice: 0, commissionPct: 20, features: 2 },
  { slug: "trusted", monthlyPrice: 199, commissionPct: 15, features: 3, featured: true },
  { slug: "featured", monthlyPrice: 499, commissionPct: 10, features: 5 },
];

export default async function PricingPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("pricing");

  return (
    <Container className="py-16">
      <header className="mb-12 text-center">
        <h1 className="text-3xl font-bold text-text sm:text-4xl">{t("title")}</h1>
        <p className="mx-auto mt-3 max-w-2xl text-text-muted">{t("subtitle")}</p>
      </header>

      <div className="grid gap-6 md:grid-cols-3">
        {TIERS.map((tier) => (
          <Card
            key={tier.slug}
            className={tier.featured ? "ring-2 ring-primary" : undefined}
          >
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle>{t(`tiers.${tier.slug}.name`)}</CardTitle>
                {tier.featured && <Badge tone="primary">{t("popular")}</Badge>}
              </div>
              <p className="mt-1 text-sm text-text-muted">{t(`tiers.${tier.slug}.tagline`)}</p>
            </CardHeader>
            <CardBody className="space-y-5">
              <div>
                <span className="text-4xl font-bold text-text">{tier.monthlyPrice}</span>{" "}
                <span className="text-text-muted">{t("perMonth")}</span>
                <p className="mt-1 text-xs text-text-muted">
                  {t("commission", { pct: tier.commissionPct })}
                </p>
              </div>
              <ul className="space-y-2">
                {Array.from({ length: tier.features }).map((_, i) => (
                  <li key={i} className="flex items-start gap-2">
                    <Check className="mt-0.5 h-4 w-4 text-success" />
                    <span className="text-sm">
                      {t(`tiers.${tier.slug}.features.${i}`)}
                    </span>
                  </li>
                ))}
              </ul>
              <Link href="/become-provider">
                <Button fullWidth variant={tier.featured ? "primary" : "outline"}>
                  {t("cta")}
                </Button>
              </Link>
            </CardBody>
          </Card>
        ))}
      </div>
    </Container>
  );
}
