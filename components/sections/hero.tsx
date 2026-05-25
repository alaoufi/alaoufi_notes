import { useTranslations } from "next-intl";
import { Container, Button } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { ArrowRight, Sparkles } from "lucide-react";

export function Hero() {
  const t = useTranslations("home");

  return (
    <section className="relative overflow-hidden border-b border-border bg-gradient-to-b from-surface to-bg pb-16 pt-16 sm:pt-24">
      <div
        className="absolute inset-0 -z-10 opacity-50"
        aria-hidden
        style={{
          backgroundImage:
            "radial-gradient(60% 50% at 50% 0%, var(--color-primary)/15, transparent 70%)",
        }}
      />
      <Container className="grid items-center gap-12 md:grid-cols-2">
        <div className="flex flex-col items-start gap-6">
          <span className="inline-flex items-center gap-1.5 rounded-pill border border-border bg-surface px-3 py-1 text-xs font-medium text-text-muted">
            <Sparkles className="h-3.5 w-3.5 text-primary" />
            <span>{t.has("badge") ? t("badge") : "v0.1 · Beta"}</span>
          </span>
          <h1 className="text-4xl font-bold leading-tight text-text sm:text-5xl">
            {t("heroTitle")}
          </h1>
          <p className="max-w-xl text-lg text-text-muted">{t("heroSubtitle")}</p>
          <div className="flex flex-wrap items-center gap-3">
            <Link href="/services">
              <Button size="lg" iconEnd={<ArrowRight className="h-5 w-5 rtl:rotate-180" />}>
                {t("ctaPrimary")}
              </Button>
            </Link>
            <Link href="/become-provider">
              <Button size="lg" variant="outline">
                {t("ctaSecondary")}
              </Button>
            </Link>
          </div>

          <dl className="mt-8 grid grid-cols-2 gap-x-8 gap-y-4 sm:grid-cols-4">
            <Stat value="12k+" label={t("statsOrders")} />
            <Stat value="850+" label={t("statsProviders")} />
            <Stat value="14" label={t("statsCities")} />
            <Stat value="4.8 ★" label={t("statsRating")} />
          </dl>
        </div>

        <div className="relative">
          <div className="aspect-square rounded-xl border border-border bg-surface p-6 shadow-lg">
            <div className="grid h-full grid-cols-2 gap-3">
              <DemoCard color="primary" label="HVAC" />
              <DemoCard color="success" label="Plumbing" />
              <DemoCard color="warning" label="Electrical" />
              <DemoCard color="info" label="Vehicle" />
            </div>
          </div>
        </div>
      </Container>
    </section>
  );
}

function Stat({ value, label }: { value: string; label: string }) {
  return (
    <div className="flex flex-col">
      <dt className="text-xs text-text-muted">{label}</dt>
      <dd className="text-xl font-semibold text-text">{value}</dd>
    </div>
  );
}

function DemoCard({
  color,
  label,
}: {
  color: "primary" | "success" | "warning" | "info";
  label: string;
}) {
  const classes: Record<typeof color, string> = {
    primary: "bg-primary/10 text-primary",
    success: "bg-success/10 text-success",
    warning: "bg-warning/10 text-warning",
    info: "bg-info/10 text-info",
  };
  return (
    <div
      className={`flex flex-col items-center justify-center rounded-lg border border-border/50 ${classes[color]} font-semibold`}
    >
      {label}
    </div>
  );
}
