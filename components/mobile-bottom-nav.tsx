"use client";

import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import { usePathname } from "@/i18n/navigation";
import { Home, Search, ClipboardList, MessageCircle, User } from "lucide-react";

interface Tab {
  href: string;
  labelKey: string;
  icon: typeof Home;
  // match-prefix list — first segment must equal one of these for "active"
  match: (path: string) => boolean;
}

const TABS: Tab[] = [
  {
    href: "/",
    labelKey: "home",
    icon: Home,
    match: (p) => p === "/" || p === "",
  },
  {
    href: "/services",
    labelKey: "services",
    icon: Search,
    match: (p) => p.startsWith("/services"),
  },
  {
    href: "/orders",
    labelKey: "orders",
    icon: ClipboardList,
    match: (p) => p.startsWith("/orders"),
  },
  {
    href: "/chat-demo",
    labelKey: "chat",
    icon: MessageCircle,
    match: (p) => p.startsWith("/chat"),
  },
  {
    href: "/profile",
    labelKey: "profile",
    icon: User,
    match: (p) => p.startsWith("/profile"),
  },
];

export function MobileBottomNav() {
  const t = useTranslations("mobileNav");
  const path = usePathname();

  // Hide on certain full-bleed routes (auth, admin) — they have their own chrome.
  if (
    path.startsWith("/sign-in") ||
    path.startsWith("/sign-up") ||
    path.startsWith("/admin") ||
    path.startsWith("/forbidden")
  ) {
    return null;
  }

  return (
    <nav
      role="navigation"
      aria-label={t("ariaLabel")}
      className="fixed inset-x-0 bottom-0 z-40 border-t border-border bg-surface/95 backdrop-blur supports-[backdrop-filter]:bg-surface/85 md:hidden"
      style={{ paddingBottom: "env(safe-area-inset-bottom)" }}
    >
      <ul className="mx-auto grid max-w-screen-sm grid-cols-5">
        {TABS.map(({ href, labelKey, icon: Icon, match }) => {
          const active = match(path);
          return (
            <li key={href} className="flex">
              <Link
                href={href}
                aria-current={active ? "page" : undefined}
                className={`flex flex-1 flex-col items-center justify-center gap-1 py-2 text-[11px] font-medium transition-colors ${
                  active ? "text-primary" : "text-text-muted hover:text-text"
                }`}
              >
                <Icon
                  className={`h-5 w-5 transition-transform ${active ? "scale-110" : ""}`}
                  aria-hidden
                />
                <span>{t(labelKey)}</span>
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
