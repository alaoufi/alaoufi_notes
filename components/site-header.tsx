"use client";

import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import { Container } from "@syanah/ui";
import { Wrench } from "lucide-react";
import { LanguageSwitcher } from "./language-switcher";
import { ThemeSwitcher } from "./theme-switcher";
import { MobileMenu } from "./mobile-menu";
import type { Locale } from "@/i18n/locales";

export function SiteHeader({
  locale,
  theme,
}: {
  locale: Locale;
  theme: "navy" | "stc" | "fuchsia";
}) {
  const t = useTranslations("nav");
  const brand = useTranslations("brand");

  return (
    <header className="sticky top-0 z-sticky border-b border-border bg-surface/95 backdrop-blur supports-[backdrop-filter]:bg-surface/85">
      <Container className="flex h-16 items-center justify-between gap-3">
        <Link href="/" className="flex items-center gap-2 font-semibold text-text">
          <span className="grid h-9 w-9 place-items-center rounded-md bg-primary text-primary-contrast shadow-sm">
            <Wrench className="h-5 w-5" />
          </span>
          <span className="text-base sm:text-lg">{brand("name")}</span>
        </Link>

        {/* desktop nav */}
        <nav className="hidden items-center gap-6 md:flex">
          <Link href="/" className="text-sm text-text-muted hover:text-text">
            {t("home")}
          </Link>
          <Link href="/services" className="text-sm text-text-muted hover:text-text">
            {t("services")}
          </Link>
          <Link href="/providers" className="text-sm text-text-muted hover:text-text">
            {t("providers")}
          </Link>
          <Link href="/how-it-works" className="text-sm text-text-muted hover:text-text">
            {t("howItWorks")}
          </Link>
          <Link href="/pricing" className="text-sm text-text-muted hover:text-text">
            {t("pricing")}
          </Link>
        </nav>

        {/* desktop actions */}
        <div className="hidden items-center gap-2 md:flex">
          <LanguageSwitcher currentLocale={locale} />
          <ThemeSwitcher currentTheme={theme} />
          <Link
            href="/sign-in"
            className="inline-flex h-10 items-center rounded-md px-4 text-sm font-medium text-text hover:bg-surface-muted"
          >
            {t("signIn")}
          </Link>
          <Link
            href="/sign-up"
            className="inline-flex h-10 items-center rounded-md bg-primary px-4 text-sm font-medium text-primary-contrast shadow-sm hover:bg-primary-hover"
          >
            {t("signUp")}
          </Link>
        </div>

        {/* mobile actions */}
        <div className="flex items-center gap-2 md:hidden">
          <Link
            href="/sign-up"
            className="inline-flex h-10 items-center rounded-md bg-primary px-3 text-sm font-medium text-primary-contrast shadow-sm hover:bg-primary-hover"
          >
            {t("signUp")}
          </Link>
          <MobileMenu locale={locale} theme={theme} />
        </div>
      </Container>
    </header>
  );
}
