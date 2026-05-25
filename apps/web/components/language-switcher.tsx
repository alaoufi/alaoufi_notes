"use client";

import { useState, useRef, useEffect } from "react";
import { useTranslations } from "next-intl";
import { Globe, Check } from "lucide-react";
import { useRouter, usePathname } from "@/i18n/navigation";
import { locales, localeNames, type Locale } from "@/i18n/locales";

export function LanguageSwitcher({ currentLocale }: { currentLocale: Locale }) {
  const t = useTranslations("nav");
  const router = useRouter();
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function onClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener("mousedown", onClick);
    return () => document.removeEventListener("mousedown", onClick);
  }, []);

  function switchTo(locale: Locale) {
    router.replace(pathname, { locale });
    setOpen(false);
  }

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label={t("language")}
        className="inline-flex h-10 items-center gap-1.5 rounded-md border border-border bg-surface px-3 text-sm hover:bg-surface-muted"
      >
        <Globe className="h-4 w-4" />
        <span className="hidden sm:inline">{localeNames[currentLocale]}</span>
      </button>
      {open && (
        <div
          role="menu"
          className="absolute end-0 mt-2 w-44 overflow-hidden rounded-md border border-border bg-surface shadow-md"
        >
          {locales.map((loc) => (
            <button
              key={loc}
              role="menuitem"
              onClick={() => switchTo(loc)}
              className="flex w-full items-center justify-between px-3 py-2 text-sm hover:bg-surface-muted"
            >
              <span>{localeNames[loc]}</span>
              {loc === currentLocale && <Check className="h-4 w-4 text-primary" />}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
