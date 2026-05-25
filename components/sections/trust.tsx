import { useTranslations } from "next-intl";
import { Container } from "@syanah/ui";
import { ShieldCheck, CreditCard, Award, type LucideIcon } from "lucide-react";

interface Pillar {
  icon: LucideIcon;
  title: string;
  body: string;
  tone: "primary" | "accent" | "success";
}

export function Trust() {
  const t = useTranslations("trustSection");

  const pillars: Pillar[] = [
    { icon: ShieldCheck, title: t("verifiedTitle"),  body: t("verifiedBody"),  tone: "primary" },
    { icon: CreditCard,  title: t("paymentTitle"),   body: t("paymentBody"),   tone: "accent"  },
    { icon: Award,       title: t("guaranteeTitle"), body: t("guaranteeBody"), tone: "success" },
  ];

  const palette: Record<Pillar["tone"], string> = {
    primary: "bg-primary/10 text-primary",
    accent: "bg-accent/10 text-accent",
    success: "bg-success/10 text-success",
  };

  return (
    <section className="py-20">
      <Container>
        <div className="grid gap-6 md:grid-cols-3">
          {pillars.map((p, i) => (
            <div
              key={i}
              className="relative overflow-hidden rounded-xl border border-border bg-surface p-6 transition-shadow hover:shadow-md"
            >
              <div
                aria-hidden
                className="pointer-events-none absolute -end-10 -top-10 h-32 w-32 rounded-full opacity-50 blur-2xl"
                style={{ background: "var(--color-surface-muted)" }}
              />
              <div className="relative space-y-4">
                <span
                  className={`grid h-12 w-12 place-items-center rounded-lg ${palette[p.tone]}`}
                >
                  <p.icon className="h-6 w-6" />
                </span>
                <h3 className="text-lg font-semibold text-text">{p.title}</h3>
                <p className="text-sm leading-relaxed text-text-muted">{p.body}</p>
              </div>
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}
