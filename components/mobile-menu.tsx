"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Link, usePathname } from "@/i18n/navigation";
import { Menu, X, ChevronRight, Globe, Palette } from "lucide-react";
import { locales, localeNames, type Locale } from "@/i18n/locales";
import { useRouter } from "@/i18n/navigation";

type Theme = "navy" | "stc" | "fuchsia";

const THEME_SWATCH: Record<Theme, { primary: string; accent: string }> = {
  navy: { primary: "#0F2D6B", accent: "#E11D2B" },
  stc: { primary: "#4F008C", accent: "#E60082" },
  fuchsia: { primary: "#C2185B", accent: "#E91E63" },
};

export function MobileMenu({ locale, theme }: { locale: Locale; theme: Theme }) {
  const t = useTranslations("nav");
  const themesT = useTranslations("themes");
  const router = useRouter();
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  useEffect(() => {
    if (!open) return;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previousOverflow;
    };
  }, [open]);

  function close() {
    setOpen(false);
  }

  function switchLocale(loc: Locale) {
    router.replace(pathname, { locale: loc });
    close();
  }

  function switchTheme(next: Theme) {
    document.documentElement.setAttribute("data-theme", next);
    // eslint-disable-next-line react-hooks/immutability -- document.cookie assignment is the standard cookie-write API.
    document.cookie = `syanah_theme=${next}; path=/; max-age=${60 * 60 * 24 * 365}; samesite=lax`;
    close();
  }

  const navLinks = [
    { href: "/" as const, label: t("home") },
    { href: "/services" as const, label: t("services") },
    { href: "/providers" as const, label: t("providers") },
    { href: "/how-it-works" as const, label: t("howItWorks") },
    { href: "/pricing" as const, label: t("pricing") },
  ];

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        aria-label="menu"
        aria-expanded={open}
        className="inline-flex h-10 w-10 items-center justify-center rounded-md border border-border bg-surface text-text hover:bg-surface-muted md:hidden"
      >
        <Menu className="h-5 w-5" />
      </button>

      {open && (
        <div
          className="fixed inset-0 z-modal flex md:hidden"
          role="dialog"
          aria-modal="true"
        >
          <div
            className="absolute inset-0 bg-overlay"
            onClick={close}
            aria-hidden
          />
          <div className="relative ms-auto flex h-full w-[88%] max-w-sm flex-col bg-surface shadow-lg">
            <div className="flex h-16 items-center justify-between border-b border-border px-4">
              <span className="text-base font-semibold text-text">{t("menu")}</span>
              <button
                type="button"
                onClick={close}
                aria-label="close"
                className="inline-flex h-10 w-10 items-center justify-center rounded-md hover:bg-surface-muted"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <nav className="flex flex-col gap-1 p-3">
              {navLinks.map((link) => (
                <Link
                  key={link.href}
                  href={link.href}
                  onClick={close}
                  className="flex items-center justify-between rounded-md px-3 py-3 text-base text-text hover:bg-surface-muted"
                >
                  <span>{link.label}</span>
                  <ChevronRight className="h-4 w-4 text-text-muted rtl:rotate-180" />
                </Link>
              ))}
            </nav>

            <div className="border-t border-border p-3">
              <p className="mb-2 flex items-center gap-2 px-2 text-xs font-semibold uppercase tracking-wider text-text-muted">
                <Globe className="h-3.5 w-3.5" />
                {t("language")}
              </p>
              <div className="flex flex-wrap gap-1.5">
                {locales.map((loc) => (
                  <button
                    key={loc}
                    type="button"
                    onClick={() => switchLocale(loc)}
                    className={`rounded-md px-3 py-2 text-sm transition-colors ${
                      loc === locale
                        ? "bg-primary text-primary-contrast"
                        : "bg-surface-muted text-text hover:bg-border"
                    }`}
                  >
                    {localeNames[loc]}
                  </button>
                ))}
              </div>
            </div>

            <div className="border-t border-border p-3">
              <p className="mb-2 flex items-center gap-2 px-2 text-xs font-semibold uppercase tracking-wider text-text-muted">
                <Palette className="h-3.5 w-3.5" />
                {t("theme")}
              </p>
              <div className="grid grid-cols-3 gap-2">
                {(["navy", "stc", "fuchsia"] as const).map((th) => (
                  <button
                    key={th}
                    type="button"
                    onClick={() => switchTheme(th)}
                    className={`flex flex-col items-center gap-1.5 rounded-md border px-2 py-2.5 text-xs transition-colors ${
                      th === theme
                        ? "border-primary bg-primary/10 text-primary"
                        : "border-border text-text hover:bg-surface-muted"
                    }`}
                  >
                    <span className="flex h-4 w-10 overflow-hidden rounded-sm">
                      <span
                        className="flex-1"
                        style={{ background: THEME_SWATCH[th].primary }}
                      />
                      <span
                        className="flex-1"
                        style={{ background: THEME_SWATCH[th].accent }}
                      />
                    </span>
                    {themesT(th)}
                  </button>
                ))}
              </div>
            </div>

            <div className="mt-auto flex flex-col gap-2 border-t border-border p-4">
              <Link
                href="/sign-in"
                onClick={close}
                className="flex h-11 items-center justify-center rounded-md border border-border text-sm font-medium text-text hover:bg-surface-muted"
              >
                {t("signIn")}
              </Link>
              <Link
                href="/sign-up"
                onClick={close}
                className="flex h-11 items-center justify-center rounded-md bg-primary text-sm font-medium text-primary-contrast shadow-sm hover:bg-primary-hover"
              >
                {t("signUp")}
              </Link>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
