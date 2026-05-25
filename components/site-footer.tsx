import { useTranslations } from "next-intl";
import { Container } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { Wrench, Mail, Phone, MapPin } from "lucide-react";

export function SiteFooter() {
  const t = useTranslations("footer");
  const nav = useTranslations("nav");
  const brand = useTranslations("brand");
  const year = new Date().getFullYear();

  return (
    <footer className="mt-section border-t border-border bg-surface">
      <Container className="py-14">
        <div className="grid gap-10 sm:grid-cols-2 lg:grid-cols-4">
          {/* Brand */}
          <div className="lg:col-span-1">
            <Link href="/" className="inline-flex items-center gap-2 font-semibold text-text">
              <span className="grid h-9 w-9 place-items-center rounded-md bg-primary text-primary-contrast shadow-sm">
                <Wrench className="h-5 w-5" />
              </span>
              <span className="text-lg">{brand("name")}</span>
            </Link>
            <p className="mt-3 max-w-xs text-sm leading-relaxed text-text-muted">
              {brand("tagline")}
            </p>
          </div>

          {/* Explore */}
          <div>
            <p className="mb-4 text-xs font-semibold uppercase tracking-[0.2em] text-text-muted">
              {t("explore")}
            </p>
            <ul className="space-y-2">
              <FooterLink href="/" label={nav("home")} />
              <FooterLink href="/services" label={nav("services")} />
              <FooterLink href="/providers" label={nav("providers")} />
              <FooterLink href="/how-it-works" label={nav("howItWorks")} />
              <FooterLink href="/pricing" label={nav("pricing")} />
            </ul>
          </div>

          {/* Legal */}
          <div>
            <p className="mb-4 text-xs font-semibold uppercase tracking-[0.2em] text-text-muted">
              {t("legal")}
            </p>
            <ul className="space-y-2">
              <FooterLink href="/privacy" label={t("privacy")} />
              <FooterLink href="/terms" label={t("terms")} />
              <FooterLink href="/contact" label={t("contact")} />
            </ul>
          </div>

          {/* Contact */}
          <div>
            <p className="mb-4 text-xs font-semibold uppercase tracking-[0.2em] text-text-muted">
              {t("contactUs")}
            </p>
            <ul className="space-y-2 text-sm text-text-muted">
              <li className="flex items-center gap-2">
                <Mail className="h-4 w-4 text-primary" />
                <a href="mailto:support@syanah.app" className="hover:text-text" dir="ltr">
                  support@syanah.app
                </a>
              </li>
              <li className="flex items-center gap-2">
                <Phone className="h-4 w-4 text-primary" />
                <a href="tel:+966112345678" className="hover:text-text" dir="ltr">
                  +966 11 234 5678
                </a>
              </li>
              <li className="flex items-center gap-2">
                <MapPin className="h-4 w-4 text-primary" />
                <span>{t("addressLine")}</span>
              </li>
            </ul>
          </div>
        </div>

        <div className="mt-10 flex flex-col items-center justify-between gap-3 border-t border-border pt-6 sm:flex-row">
          <p className="text-sm text-text-muted">{t("tagline")}</p>
          <p className="text-xs text-text-muted">
            © {year} {brand("name")} · {t("rights")}
          </p>
        </div>
      </Container>
    </footer>
  );
}

function FooterLink({ href, label }: { href: string; label: string }) {
  return (
    <li>
      <Link
        href={href}
        className="inline-block text-sm text-text-muted transition-colors hover:text-text"
      >
        {label}
      </Link>
    </li>
  );
}
