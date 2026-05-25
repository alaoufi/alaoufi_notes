import { useTranslations } from "next-intl";
import { Container } from "@syanah/ui";
import { Link } from "@/i18n/navigation";

export function SiteFooter() {
  const t = useTranslations("footer");
  const year = new Date().getFullYear();

  return (
    <footer className="mt-section border-t border-border bg-surface">
      <Container className="flex flex-col items-center justify-between gap-4 py-8 sm:flex-row">
        <p className="text-sm text-text-muted">{t("tagline")}</p>
        <nav className="flex items-center gap-4 text-sm">
          <Link href="/privacy" className="text-text-muted hover:text-text">
            {t("privacy")}
          </Link>
          <Link href="/terms" className="text-text-muted hover:text-text">
            {t("terms")}
          </Link>
          <Link href="/contact" className="text-text-muted hover:text-text">
            {t("contact")}
          </Link>
        </nav>
        <p className="text-xs text-text-muted">© {year} — {t("rights")}</p>
      </Container>
    </footer>
  );
}
