import { useTranslations } from "next-intl";
import { Container } from "@syanah/ui";
import { Search, UserCheck, MapPin } from "lucide-react";

export function HowItWorks() {
  const t = useTranslations("howItWorks");

  const steps = [
    { icon: Search, title: t("step1Title"), body: t("step1Body") },
    { icon: UserCheck, title: t("step2Title"), body: t("step2Body") },
    { icon: MapPin, title: t("step3Title"), body: t("step3Body") },
  ];

  return (
    <section className="bg-surface-muted/40 py-16">
      <Container>
        <h2 className="mb-10 text-center text-2xl font-bold text-text sm:text-3xl">
          {t("title")}
        </h2>
        <ol className="grid gap-6 md:grid-cols-3">
          {steps.map((step, i) => (
            <li
              key={i}
              className="relative rounded-lg border border-border bg-surface p-6 shadow-sm"
            >
              <span
                aria-hidden
                className="absolute -top-3 start-6 grid h-7 w-7 place-items-center rounded-pill bg-primary text-sm font-bold text-primary-contrast"
              >
                {i + 1}
              </span>
              <step.icon className="mb-4 h-6 w-6 text-primary" />
              <h3 className="mb-2 text-lg font-semibold text-text">{step.title}</h3>
              <p className="text-text-muted">{step.body}</p>
            </li>
          ))}
        </ol>
      </Container>
    </section>
  );
}
