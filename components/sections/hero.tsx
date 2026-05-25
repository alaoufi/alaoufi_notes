import { useTranslations } from "next-intl";
import { Container, Button } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { ArrowRight, ShieldCheck, Star, Clock, MapPin } from "lucide-react";

export function Hero() {
  const t = useTranslations("home");

  return (
    <section className="relative isolate overflow-hidden bg-bg pb-20 pt-12 sm:pt-20 lg:pt-28">
      {/* decorative gradient blobs — adapt to active theme */}
      <div aria-hidden className="pointer-events-none absolute inset-0 -z-10 overflow-hidden">
        <div
          className="absolute -top-32 start-[-10%] h-[460px] w-[460px] rounded-full opacity-30 blur-3xl"
          style={{
            background:
              "radial-gradient(circle at 30% 30%, var(--color-primary) 0%, transparent 70%)",
          }}
        />
        <div
          className="absolute bottom-[-20%] end-[-10%] h-[420px] w-[420px] rounded-full opacity-25 blur-3xl"
          style={{
            background:
              "radial-gradient(circle at 70% 70%, var(--color-accent) 0%, transparent 70%)",
          }}
        />
        <div
          className="absolute inset-0 opacity-[0.04]"
          style={{
            backgroundImage: "radial-gradient(currentColor 1px, transparent 1px)",
            backgroundSize: "32px 32px",
            color: "var(--color-text)",
          }}
        />
      </div>

      <Container className="grid items-center gap-12 lg:grid-cols-[1.1fr_1fr]">
        <div className="flex flex-col items-start gap-7">
          <span className="inline-flex items-center gap-2 rounded-pill border border-border bg-surface px-4 py-1.5 text-xs font-medium text-text shadow-sm">
            <span className="relative flex h-2 w-2">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-success opacity-75" />
              <span className="relative inline-flex h-2 w-2 rounded-full bg-success" />
            </span>
            <span>{t("badge")}</span>
          </span>

          <h1 className="text-4xl font-bold leading-[1.15] text-text sm:text-5xl lg:text-6xl">
            {t("heroTitle")}
            <span
              className="block bg-clip-text text-transparent"
              style={{
                backgroundImage:
                  "linear-gradient(135deg, var(--color-primary) 0%, var(--color-accent) 100%)",
              }}
            >
              {t("heroTitleAccent")}
            </span>
          </h1>

          <p className="max-w-xl text-lg leading-relaxed text-text-muted">
            {t("heroSubtitle")}
          </p>

          <div className="flex w-full flex-wrap items-center gap-3">
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

          <ul className="flex flex-wrap items-center gap-x-6 gap-y-2 pt-2 text-sm text-text-muted">
            <li className="inline-flex items-center gap-1.5">
              <ShieldCheck className="h-4 w-4 text-success" />
              {t("trust.verified")}
            </li>
            <li className="inline-flex items-center gap-1.5">
              <Clock className="h-4 w-4 text-info" />
              {t("trust.fast")}
            </li>
            <li className="inline-flex items-center gap-1.5">
              <Star className="h-4 w-4 fill-warning text-warning" />
              {t("trust.rated")}
            </li>
          </ul>
        </div>

        <div className="relative">
          <div className="absolute -top-4 start-[-8%] z-10 hidden max-w-[220px] rounded-lg border border-border bg-surface p-3 shadow-lg sm:block">
            <div className="flex items-center gap-2">
              <div className="grid h-9 w-9 place-items-center rounded-pill bg-primary/10 font-bold text-primary">
                ن
              </div>
              <div>
                <div className="flex items-center gap-0.5">
                  {Array.from({ length: 5 }).map((_, i) => (
                    <Star key={i} className="h-3 w-3 fill-warning text-warning" />
                  ))}
                </div>
                <p className="text-xs text-text-muted">{t("quote.author")}</p>
              </div>
            </div>
            <p className="mt-2 text-xs leading-relaxed text-text">{t("quote.body")}</p>
          </div>

          <div className="absolute -bottom-4 end-[-6%] z-10 hidden rounded-lg border border-border bg-surface p-3 shadow-lg sm:block">
            <div className="flex items-center gap-2">
              <span className="grid h-9 w-9 place-items-center rounded-pill bg-accent/10 text-accent">
                <MapPin className="h-4 w-4" />
              </span>
              <div>
                <p className="text-xs text-text-muted">{t("eta.label")}</p>
                <p className="text-sm font-bold text-text">{t("eta.value")}</p>
              </div>
            </div>
          </div>

          <div className="relative aspect-square rounded-xl border border-border bg-surface p-5 shadow-lg">
            <div className="grid h-full grid-cols-2 grid-rows-2 gap-3">
              <DemoTile color="primary" label={t("demo.hvac")} symbol="❄" />
              <DemoTile color="success" label={t("demo.plumbing")} symbol="💧" />
              <DemoTile color="warning" label={t("demo.electrical")} symbol="⚡" />
              <DemoTile color="accent" label={t("demo.vehicle")} symbol="🛠" />
            </div>
          </div>
        </div>
      </Container>

      <Container className="mt-14">
        <div className="grid grid-cols-2 gap-px overflow-hidden rounded-lg border border-border bg-border shadow-sm sm:grid-cols-4">
          <Stat value="12,000+" label={t("statsOrders")} />
          <Stat value="850+" label={t("statsProviders")} />
          <Stat value="14" label={t("statsCities")} />
          <Stat value="4.8 ★" label={t("statsRating")} />
        </div>
      </Container>
    </section>
  );
}

function Stat({ value, label }: { value: string; label: string }) {
  return (
    <div className="bg-surface px-4 py-5 text-center sm:px-6 sm:py-6 sm:text-start">
      <p className="text-2xl font-bold text-text sm:text-3xl">{value}</p>
      <p className="mt-1 text-xs text-text-muted sm:text-sm">{label}</p>
    </div>
  );
}

function DemoTile({
  color,
  label,
  symbol,
}: {
  color: "primary" | "success" | "warning" | "accent";
  label: string;
  symbol: string;
}) {
  const palette: Record<typeof color, string> = {
    primary: "bg-primary/10 text-primary",
    success: "bg-success/10 text-success",
    warning: "bg-warning/10 text-warning",
    accent: "bg-accent/10 text-accent",
  };
  return (
    <div
      className={`flex flex-col items-center justify-center gap-2 rounded-lg border border-border/40 font-semibold transition-transform hover:scale-[1.02] ${palette[color]}`}
    >
      <span className="text-3xl" aria-hidden>{symbol}</span>
      <span className="text-sm">{label}</span>
    </div>
  );
}
