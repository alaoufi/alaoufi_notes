"use client";

import { useTranslations } from "next-intl";
import { Palette } from "lucide-react";

type Theme = "soft-blue" | "pink";

export function ThemeSwitcher({ currentTheme }: { currentTheme: Theme }) {
  const t = useTranslations("nav");

  function toggle() {
    const next: Theme = currentTheme === "soft-blue" ? "pink" : "soft-blue";
    document.documentElement.dataset.theme = next;
    document.cookie = `syanah_theme=${next}; path=/; max-age=${60 * 60 * 24 * 365}; samesite=lax`;
  }

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label={t("theme")}
      className="inline-flex h-10 w-10 items-center justify-center rounded-md border border-border bg-surface hover:bg-surface-muted"
    >
      <Palette className="h-4 w-4" />
    </button>
  );
}
