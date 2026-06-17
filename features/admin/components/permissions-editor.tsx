"use client";

import { useState, useTransition } from "react";
import { useTranslations } from "next-intl";
import { Button, Input, Card, CardBody, Badge } from "@syanah/ui";
import {
  grantSectionAction,
  revokeSectionAction,
  searchUsersForPromotion,
  type SectionAdminRow,
  type UserSearchResult,
} from "../server/permissions";
import { ADMIN_SECTIONS, type AdminSection } from "@/lib/auth/sections-shared";
import { Search, UserPlus, X, ShieldCheck, AlertCircle } from "lucide-react";

interface Props {
  initialRows: SectionAdminRow[];
}

export function PermissionsEditor({ initialRows }: Props) {
  const t = useTranslations("admin.permissions");
  const [rows, setRows] = useState<SectionAdminRow[]>(initialRows);
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const [query, setQuery] = useState("");
  const [results, setResults] = useState<UserSearchResult[]>([]);
  const [searching, startSearch] = useTransition();

  function toggle(userId: string, section: AdminSection, on: boolean) {
    setError(null);
    setRows((cur) =>
      cur.map((r) =>
        r.userId === userId
          ? {
              ...r,
              sections: on
                ? Array.from(new Set([...r.sections, section]))
                : r.sections.filter((s) => s !== section),
            }
          : r,
      ),
    );

    startTransition(async () => {
      const res = on
        ? await grantSectionAction(userId, section)
        : await revokeSectionAction(userId, section);
      if (!res.ok) {
        setError(res.errorKey ?? "admin.permissions.errors.grantFailed");
        // rollback
        setRows((cur) =>
          cur.map((r) =>
            r.userId === userId
              ? {
                  ...r,
                  sections: on
                    ? r.sections.filter((s) => s !== section)
                    : Array.from(new Set([...r.sections, section])),
                }
              : r,
          ),
        );
      } else if (!on) {
        // If user has no sections left we still keep them in the UI so the
        // super_admin can re-add — the row will disappear on next page load.
      }
    });
  }

  function runSearch(value: string) {
    setQuery(value);
    if (value.trim().length < 2) {
      setResults([]);
      return;
    }
    startSearch(async () => {
      const r = await searchUsersForPromotion(value);
      setResults(r);
    });
  }

  function promote(user: UserSearchResult, section: AdminSection) {
    setError(null);
    setResults([]);
    setQuery("");

    // Optimistically add the row if it isn't already there.
    setRows((cur) => {
      if (cur.some((r) => r.userId === user.userId)) {
        return cur.map((r) =>
          r.userId === user.userId
            ? { ...r, sections: Array.from(new Set([...r.sections, section])) }
            : r,
        );
      }
      return [
        ...cur,
        {
          userId: user.userId,
          fullName: user.fullName,
          email: user.email,
          username: user.username,
          sections: [section],
        },
      ];
    });

    startTransition(async () => {
      const res = await grantSectionAction(user.userId, section);
      if (!res.ok) {
        setError(res.errorKey ?? "admin.permissions.errors.grantFailed");
        setRows((cur) => cur.filter((r) => r.userId !== user.userId));
      }
    });
  }

  return (
    <div className="space-y-6">
      {error && (
        <Card>
          <CardBody className="flex items-center gap-2 text-error">
            <AlertCircle className="h-5 w-5" />
            <span className="text-sm">{t.has(error.replace("admin.permissions.", ""))
              ? t(error.replace("admin.permissions.", ""))
              : error}</span>
          </CardBody>
        </Card>
      )}

      <Card>
        <CardBody className="space-y-4">
          <div>
            <h2 className="flex items-center gap-2 text-lg font-semibold">
              <UserPlus className="h-5 w-5" /> {t("addAdmin.title")}
            </h2>
            <p className="text-sm text-text-muted">{t("addAdmin.subtitle")}</p>
          </div>
          <div className="relative">
            <Search className="pointer-events-none absolute start-3 top-1/2 h-4 w-4 -translate-y-1/2 text-text-muted" />
            <Input
              className="ps-9"
              placeholder={t("addAdmin.searchPlaceholder")}
              value={query}
              onChange={(e) => runSearch(e.target.value)}
            />
          </div>
          {searching && <p className="text-xs text-text-muted">{t("addAdmin.searching")}</p>}
          {!searching && query.trim().length >= 2 && results.length === 0 && (
            <p className="text-xs text-text-muted">{t("addAdmin.noResults")}</p>
          )}
          {results.length > 0 && (
            <div className="space-y-2">
              {results.map((u) => (
                <div
                  key={u.userId}
                  className="flex flex-col gap-2 rounded-md border border-border p-3 sm:flex-row sm:items-center sm:justify-between"
                >
                  <div className="min-w-0">
                    <p className="truncate font-medium">
                      {u.fullName || u.username || u.email || u.userId.slice(0, 8)}
                    </p>
                    <p className="truncate text-xs text-text-muted">
                      {[u.username && `@${u.username}`, u.email]
                        .filter(Boolean)
                        .join(" · ") || u.userId}
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-1">
                    {ADMIN_SECTIONS.map((s) => (
                      <button
                        key={s}
                        type="button"
                        className="rounded-md border border-border px-2 py-1 text-xs hover:bg-surface-muted"
                        disabled={pending}
                        onClick={() => promote(u, s)}
                      >
                        + {t(`sections.${s}`)}
                      </button>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardBody>
      </Card>

      <div className="space-y-3">
        <h2 className="flex items-center gap-2 text-lg font-semibold">
          <ShieldCheck className="h-5 w-5" /> {t("list.title")}
        </h2>
        {rows.length === 0 && (
          <Card>
            <CardBody className="text-sm text-text-muted">{t("list.empty")}</CardBody>
          </Card>
        )}
        {rows.map((row) => (
          <Card key={row.userId}>
            <CardBody className="space-y-3">
              <div className="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
                <div className="min-w-0">
                  <p className="truncate font-medium">
                    {row.fullName || row.username || row.email || row.userId.slice(0, 8)}
                  </p>
                  <p className="truncate text-xs text-text-muted">
                    {[row.username && `@${row.username}`, row.email]
                      .filter(Boolean)
                      .join(" · ") || row.userId}
                  </p>
                </div>
                <Badge tone="primary">{t("badge")}</Badge>
              </div>
              <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-3">
                {ADMIN_SECTIONS.map((section) => {
                  const enabled = row.sections.includes(section);
                  return (
                    <label
                      key={section}
                      className={`flex cursor-pointer items-center gap-2 rounded-md border px-3 py-2 text-sm transition ${
                        enabled
                          ? "border-primary bg-primary/5 text-text"
                          : "border-border text-text-muted hover:bg-surface-muted"
                      }`}
                    >
                      <input
                        type="checkbox"
                        className="h-4 w-4"
                        checked={enabled}
                        disabled={pending}
                        onChange={(e) => toggle(row.userId, section, e.target.checked)}
                      />
                      <span>{t(`sections.${section}`)}</span>
                    </label>
                  );
                })}
              </div>
              {row.sections.length === 0 && (
                <p className="flex items-center gap-1 text-xs text-text-muted">
                  <X className="h-3 w-3" />
                  {t("list.noSections")}
                </p>
              )}
            </CardBody>
          </Card>
        ))}
      </div>
    </div>
  );
}
