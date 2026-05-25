import { useTranslations } from "next-intl";
import { Container, Button } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { TrendingUp, Calendar, Wallet, ArrowRight } from "lucide-react";

export function ProvidersCta() {
  const t = useTranslations("providersCta");

  return (
    <section className="py-20">
      <Container>
        <div
          className="relative isolate overflow-hidden rounded-2xl p-8 text-text-inverse shadow-lg sm:p-12 lg:p-14"
          style={{
            backgroundImage:
              "linear-gradient(135deg, var(--color-surface-strong) 0%, var(--color-primary) 60%, var(--color-accent) 130%)",
          }}
        >
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 opacity-10"
            style={{
              backgroundImage: "radial-gradient(currentColor 1px, transparent 1px)",
              backgroundSize: "24px 24px",
              color: "white",
            }}
          />
          <div
            aria-hidden
            className="pointer-events-none absolute -end-20 -top-20 h-72 w-72 rounded-full opacity-30 blur-3xl"
            style={{ background: "var(--color-accent)" }}
          />

          <div className="relative grid items-center gap-10 lg:grid-cols-[1.2fr_1fr]">
            <div>
              <span className="inline-block rounded-pill bg-white/15 px-3 py-1 text-xs font-medium backdrop-blur">
                {t("badge")}
              </span>
              <h2 className="mt-4 text-3xl font-bold leading-tight sm:text-4xl lg:text-5xl">
                {t("title")}
              </h2>
              <p className="mt-4 max-w-xl text-base leading-relaxed text-white/85 sm:text-lg">
                {t("body")}
              </p>
              <div className="mt-6 flex flex-wrap gap-3">
                <Link href="/become-provider">
                  <Button
                    size="lg"
                    className="bg-primary-contrast text-text hover:bg-primary-contrast/90"
                    iconEnd={<ArrowRight className="h-5 w-5 rtl:rotate-180" />}
                  >
                    {t("cta")}
                  </Button>
                </Link>
                <Link href="/pricing">
                  <Button
                    size="lg"
                    variant="outline"
                    className="border-white/40 text-white hover:bg-white/10"
                  >
                    {t("pricingCta")}
                  </Button>
                </Link>
              </div>
            </div>

            <ul className="grid gap-4 sm:grid-cols-3 lg:grid-cols-1">
              <Perk icon={Calendar} title={t("perks.demand.title")} body={t("perks.demand.body")} />
              <Perk icon={Wallet} title={t("perks.payouts.title")} body={t("perks.payouts.body")} />
              <Perk
                icon={TrendingUp}
                title={t("perks.growth.title")}
                body={t("perks.growth.body")}
              />
            </ul>
          </div>
        </div>
      </Container>
    </section>
  );
}

function Perk({
  icon: Icon,
  title,
  body,
}: {
  icon: typeof TrendingUp;
  title: string;
  body: string;
}) {
  return (
    <li className="flex items-start gap-3 rounded-lg bg-white/10 p-4 backdrop-blur">
      <span className="grid h-9 w-9 flex-shrink-0 place-items-center rounded-md bg-white/15">
        <Icon className="h-4 w-4 text-white" />
      </span>
      <div>
        <p className="text-sm font-semibold text-white">{title}</p>
        <p className="mt-0.5 text-xs leading-relaxed text-white/75">{body}</p>
      </div>
    </li>
  );
}
