"use client";

import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import { Bell, MessageCircle, ClipboardList, CreditCard, Star, Info, Check } from "lucide-react";
import type { AppNotification, NotificationKind } from "./types";

const KIND_ICON: Record<NotificationKind, typeof Bell> = {
  order_update:  ClipboardList,
  chat_message:  MessageCircle,
  payment:       CreditCard,
  rating:        Star,
  system:        Info,
};

/**
 * Bell button + dropdown panel. Notifications are passed from the parent
 * (initially empty / sample); once we wire a Supabase Realtime channel on
 * `notifications` rows for the current user, the parent can stream updates in.
 */
export function NotificationsBell({
  initial = [],
}: {
  initial?: AppNotification[];
}) {
  const t = useTranslations("notifications");
  const [items, setItems] = useState<AppNotification[]>(initial);
  const [open, setOpen] = useState(false);
  const panelRef = useRef<HTMLDivElement>(null);

  const unread = items.filter((n) => !n.readAt).length;

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (!panelRef.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", onDown);
    return () => document.removeEventListener("mousedown", onDown);
  }, [open]);

  function markAllRead() {
    const now = new Date().toISOString();
    setItems((cur) => cur.map((n) => (n.readAt ? n : { ...n, readAt: now })));
  }

  return (
    <div className="relative">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="relative grid h-10 w-10 place-items-center rounded-md text-text hover:bg-surface-muted"
        aria-label={t("ariaLabel")}
        aria-expanded={open}
      >
        <Bell className="h-5 w-5" />
        {unread > 0 && (
          <span
            className="absolute -top-0.5 -end-0.5 grid h-4 min-w-4 place-items-center rounded-pill bg-danger px-1 text-[10px] font-bold text-white"
            aria-label={t("unreadCount", { count: unread })}
          >
            {unread > 9 ? "9+" : unread}
          </span>
        )}
      </button>

      {open && (
        <div
          ref={panelRef}
          role="dialog"
          aria-label={t("ariaLabel")}
          className="absolute end-0 top-full z-40 mt-2 w-80 rounded-lg border border-border bg-surface shadow-lg"
        >
          <div className="flex items-center justify-between border-b border-border px-3 py-2">
            <h3 className="text-sm font-semibold">{t("title")}</h3>
            {unread > 0 && (
              <button
                type="button"
                onClick={markAllRead}
                className="inline-flex items-center gap-1 text-xs text-primary hover:underline"
              >
                <Check className="h-3 w-3" />
                {t("markAllRead")}
              </button>
            )}
          </div>
          <div className="max-h-96 overflow-y-auto">
            {items.length === 0 ? (
              <p className="px-4 py-10 text-center text-sm text-text-muted">{t("empty")}</p>
            ) : (
              <ul className="divide-y divide-border">
                {items.map((n) => {
                  const Icon = KIND_ICON[n.kind] ?? Bell;
                  const inner = (
                    <>
                      <span className="grid h-8 w-8 shrink-0 place-items-center rounded-md bg-primary/10 text-primary">
                        <Icon className="h-4 w-4" />
                      </span>
                      <div className="min-w-0 flex-1">
                        <p className="text-sm font-medium text-text">
                          {n.title ?? (n.titleKey ? t(n.titleKey) : "")}
                        </p>
                        {n.body && (
                          <p className="line-clamp-2 text-xs text-text-muted">{n.body}</p>
                        )}
                        <p className="mt-1 text-[10px] text-text-muted">
                          {new Date(n.createdAt).toLocaleString(undefined, {
                            hour: "2-digit",
                            minute: "2-digit",
                            day: "numeric",
                            month: "short",
                          })}
                        </p>
                      </div>
                    </>
                  );
                  const itemClass = "flex items-start gap-3 px-3 py-3 hover:bg-surface-muted";
                  return (
                    <li key={n.id} className={n.readAt ? "" : "bg-primary/5"}>
                      {n.href ? (
                        <Link href={n.href} onClick={() => setOpen(false)} className={itemClass}>
                          {inner}
                        </Link>
                      ) : (
                        <div className={itemClass}>{inner}</div>
                      )}
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
