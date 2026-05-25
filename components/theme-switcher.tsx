"use client";

import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { Palette, Check } from "lucide-react";

type Theme = "navy" | "stc" | "fuchsia";

const ORDER: Theme[] = ["navy", "stc", "fuchsia"];

// Color swatches to preview each theme's primary + accent in the dropdown.
const SWATCH: Record<Theme, { primary: string; accent: string }> = {
  navy: { primary: "#0F2D6B", accent: "#E11D2B" },
  stc: { primary: "#4F008C", accent: "#E60082" },
  fuchsia: { primary: "#C2185B", accent: "#E91E63" },
};

export function ThemeSwitcher({ currentTheme }: { currentTheme: Theme }) {
  const t = useTranslations("nav");
  const themesT = useTranslations("themes");
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function onClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener("mousedown", onClick);
    return () => document.removeEventListener("mousedown", onClick);
  }, []);

  function pick(next: Theme) {
    document.documentElement.setAttribute("data-theme", next);
    // eslint-disable-next-line react-hooks/immutability -- document.cookie assignment is the standard cookie-write API.
    document.cookie = `syanah_theme=${next}; path=/; max-age=${60 * 60 * 24 * 365}; samesite=lax`;
    setOpen(false);
  }

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label={t("theme")}
        className="inline-flex h-10 w-10 items-center justify-center rounded-md border border-border bg-surface hover:bg-surface-muted"
      >
        <Palette className="h-4 w-4" />
      </button>
      {open && (
        <div
          role="menu"
          className="absolute end-0 mt-2 w-44 overflow-hidden rounded-md border border-border bg-surface shadow-md"
        >
          {ORDER.map((th) => (
            <button
              key={th}
              role="menuitem"
              onClick={() => pick(th)}
              className="flex w-full items-center justify-between px-3 py-2 text-sm hover:bg-surface-muted"
            >
              <span className="flex items-center gap-2">
                <span className="flex">
                  <span
                    className="h-3.5 w-3.5 rounded-s-sm"
                    style={{ background: SWATCH[th].primary }}
                  />
                  <span
                    className="h-3.5 w-3.5 rounded-e-sm"
                    style={{ background: SWATCH[th].accent }}
                  />
                </span>
                <span>{themesT(th)}</span>
              </span>
              {th === currentTheme && <Check className="h-4 w-4 text-primary" />}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
