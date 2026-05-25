import { useTranslations } from "next-intl";
import { Container } from "@syanah/ui";
import { Search, UserCheck, MapPin, type LucideIcon } from "lucide-react";

interface Step {
  icon: LucideIcon;
  title: string;
  body: string;
}

export function HowItWorks() {
  const t = useTranslations("howItWorks");

  const steps: Step[] = [
    { icon: Search, title: t("step1Title"), body: t("step1Body") },
    { icon: UserCheck, title: t("step2Title"), body: t("step2Body") },
    { icon: MapPin, title: t("step3Title"), body: t("step3Body") },
  ];

  return (
    <section className="relative overflow-hidden bg-surface-muted py-20">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-x-0 top-0 h-px"
        style={{
          background:
            "linear-gradient(90deg, transparent 0%, var(--color-primary) 50%, transparent 100%)",
          opacity: 0.3,
        }}
      />

      <Container>
        <div className="mx-auto mb-14 flex max-w-2xl flex-col items-center gap-3 text-center">
          <span className="text-xs font-semibold uppercase tracking-[0.2em] text-primary">
            {t("eyebrow")}
          </span>
          <h2 className="text-3xl font-bold text-text sm:text-4xl">{t("title")}</h2>
          <p className="text-text-muted">{t("subtitle")}</p>
        </div>

        <div className="relative">
          <div
            aria-hidden
            className="absolute start-0 end-0 top-7 hidden h-px md:block"
            style={{
              background:
                "repeating-linear-gradient(90deg, var(--color-border-strong) 0 6px, transparent 6px 14px)",
            }}
          />

          <ol className="relative grid gap-8 md:grid-cols-3">
            {steps.map((step, i) => (
              <li key={i} className="relative flex flex-col items-center gap-4 text-center">
                <div className="relative z-10 grid h-14 w-14 place-items-center rounded-pill bg-surface shadow-md ring-2 ring-primary/20">
                  <span
                    className="absolute -inset-1 rounded-pill opacity-30 blur-md"
                    style={{ background: "var(--color-primary)" }}
                    aria-hidden
                  />
                  <step.icon className="relative h-6 w-6 text-primary" />
                  <span className="absolute -end-1 -top-1 grid h-6 w-6 place-items-center rounded-pill bg-primary text-xs font-bold text-primary-contrast shadow-sm">
                    {i + 1}
                  </span>
                </div>
                <h3 className="text-lg font-semibold text-text">{step.title}</h3>
                <p className="max-w-xs text-sm leading-relaxed text-text-muted">{step.body}</p>
              </li>
            ))}
          </ol>
        </div>
      </Container>
    </section>
  );
}
