import { useTranslations } from "next-intl";
import { Container } from "@syanah/ui";
import { Star, Quote } from "lucide-react";

interface Testimonial {
  initial: string;
  nameKey: string;
  cityKey: string;
  bodyKey: string;
  rating: number;
}

const ITEMS: Testimonial[] = [
  { initial: "ن", nameKey: "t1.name", cityKey: "t1.city", bodyKey: "t1.body", rating: 5 },
  { initial: "أ", nameKey: "t2.name", cityKey: "t2.city", bodyKey: "t2.body", rating: 5 },
  { initial: "س", nameKey: "t3.name", cityKey: "t3.city", bodyKey: "t3.body", rating: 4 },
];

export function Testimonials() {
  const t = useTranslations("testimonials");

  return (
    <section className="bg-surface-muted py-20">
      <Container>
        <div className="mx-auto mb-12 flex max-w-2xl flex-col items-center gap-3 text-center">
          <span className="text-xs font-semibold uppercase tracking-[0.2em] text-primary">
            {t("eyebrow")}
          </span>
          <h2 className="text-3xl font-bold text-text sm:text-4xl">{t("title")}</h2>
          <p className="text-text-muted">{t("subtitle")}</p>
        </div>

        <div className="grid gap-6 md:grid-cols-3">
          {ITEMS.map((item, i) => (
            <figure
              key={i}
              className="relative flex flex-col gap-5 rounded-xl border border-border bg-surface p-6 shadow-sm"
            >
              <Quote
                className="absolute end-5 top-5 h-7 w-7 text-primary/15"
                aria-hidden
              />
              <div className="flex items-center gap-1">
                {Array.from({ length: 5 }).map((_, idx) => (
                  <Star
                    key={idx}
                    className={`h-4 w-4 ${
                      idx < item.rating ? "fill-warning text-warning" : "text-border"
                    }`}
                  />
                ))}
              </div>
              <blockquote className="flex-1 text-text">{t(item.bodyKey)}</blockquote>
              <figcaption className="flex items-center gap-3 border-t border-border pt-4">
                <span
                  aria-hidden
                  className="grid h-10 w-10 place-items-center rounded-pill bg-primary text-primary-contrast font-bold"
                >
                  {item.initial}
                </span>
                <div>
                  <p className="text-sm font-semibold text-text">{t(item.nameKey)}</p>
                  <p className="text-xs text-text-muted">{t(item.cityKey)}</p>
                </div>
              </figcaption>
            </figure>
          ))}
        </div>
      </Container>
    </section>
  );
}
