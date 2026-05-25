"use client";

import { useMemo, useState, useTransition } from "react";
import { useTranslations } from "next-intl";
import { Button, Input, Badge } from "@syanah/ui";
import { saveTranslations } from "../server/translations";
import { autoTranslateAction } from "../server/auto-translate";
import { locales, localeNames, type Locale } from "@/i18n/locales";
import { Search, Save, RotateCcw, CheckCircle2, AlertCircle, Languages, Sparkles } from "lucide-react";

export interface EditorRow {
  key: string;
  defaults: Record<Locale, string>;
  overrides: Record<Locale, string>;
}

export function TranslationsEditor({ rows }: { rows: EditorRow[] }) {
  const t = useTranslations("admin.translations");

  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
  const pageSize = 25;

  // Map of "key|locale" → current edit value (overrides only).
  const [edits, setEdits] = useState<Record<string, string>>({});
  const [pending, startTransition] = useTransition();
  const [translating, startTranslate] = useTransition();
  const [status, setStatus] = useState<"idle" | "ok" | "fail" | "translated">("idle");
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const filtered = useMemo(() => {
    if (!query.trim()) return rows;
    const q = query.toLowerCase();
    return rows.filter((r) => {
      if (r.key.toLowerCase().includes(q)) return true;
      for (const loc of locales) {
        const v = r.overrides[loc] || r.defaults[loc] || "";
        if (v.toLowerCase().includes(q)) return true;
      }
      return false;
    });
  }, [rows, query]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / pageSize));
  const visible = filtered.slice((page - 1) * pageSize, page * pageSize);

  function editKey(key: string, locale: Locale, value: string) {
    setEdits((cur) => ({ ...cur, [`${key}|${locale}`]: value }));
    setStatus("idle");
  }

  function valueFor(row: EditorRow, locale: Locale): string {
    const editKeyName = `${row.key}|${locale}`;
    if (editKeyName in edits) return edits[editKeyName] ?? "";
    return row.overrides[locale] ?? row.defaults[locale] ?? "";
  }

  function isCustomised(row: EditorRow, locale: Locale): boolean {
    const editKeyName = `${row.key}|${locale}`;
    if (editKeyName in edits) {
      return (edits[editKeyName] ?? "") !== (row.defaults[locale] ?? "");
    }
    return Boolean(row.overrides[locale]) &&
      row.overrides[locale] !== row.defaults[locale];
  }

  function revertRow(row: EditorRow) {
    const next = { ...edits };
    for (const loc of locales) {
      next[`${row.key}|${loc}`] = row.defaults[loc] ?? "";
    }
    setEdits(next);
  }

  function pendingEdits(): { key: string; locale: Locale; value: string }[] {
    const list: { key: string; locale: Locale; value: string }[] = [];
    for (const [composite, value] of Object.entries(edits)) {
      const parts = composite.split("|");
      const key = parts[0];
      const locale = parts[1] as Locale;
      if (!key || !locales.includes(locale)) continue;
      list.push({ key, locale, value });
    }
    return list;
  }

  function save() {
    setStatus("idle");
    setErrorMsg(null);
    const updates = pendingEdits();
    if (updates.length === 0) return;
    startTransition(async () => {
      const res = await saveTranslations(updates);
      if (res.ok) {
        setStatus("ok");
        setEdits({});
      } else {
        setStatus("fail");
        setErrorMsg(res.errorKey ?? null);
      }
    });
  }

  /**
   * Translate every Arabic edit currently pending into en/ur/hi/bn through
   * the Google Translation API. The output lands in the editor — admin can
   * still tweak before saving.
   *
   * If the admin hasn't typed anything yet but wants to seed the missing
   * non-Arabic copies for the visible rows, we fall back to the row's
   * current Arabic value.
   */
  function autoTranslateAll() {
    setStatus("idle");
    setErrorMsg(null);

    const sources: { key: string; arabic: string }[] = [];

    // Prefer pending Arabic edits.
    for (const [composite, value] of Object.entries(edits)) {
      const parts = composite.split("|");
      const locale = parts[1] as Locale;
      const key = parts[0];
      if (locale === "ar" && key && value.trim()) {
        sources.push({ key, arabic: value });
      }
    }

    // If nothing was edited, translate any visible rows that have Arabic but
    // are missing at least one other locale.
    if (sources.length === 0) {
      for (const row of visible) {
        const ar = valueFor(row, "ar");
        if (!ar.trim()) continue;
        const missingAny = locales.some(
          (loc) => loc !== "ar" && !valueFor(row, loc).trim(),
        );
        if (missingAny) sources.push({ key: row.key, arabic: ar });
      }
    }

    if (sources.length === 0) return;

    startTranslate(async () => {
      const res = await autoTranslateAction(sources);
      if (!res.ok || !res.translations) {
        setStatus("fail");
        setErrorMsg(res.errorKey ?? null);
        return;
      }
      // Drop the translated values into the edit map so the admin sees them
      // and can adjust before saving.
      setEdits((cur) => {
        const next = { ...cur };
        for (const [key, perLocale] of Object.entries(res.translations!)) {
          for (const loc of ["en", "ur", "hi", "bn"] as Locale[]) {
            const translated = perLocale[loc];
            if (translated) {
              next[`${key}|${loc}`] = translated;
            }
          }
        }
        return next;
      });
      setStatus("translated");
    });
  }

  const pendingCount = Object.keys(edits).length;
  const arabicEditCount = Object.keys(edits).filter((k) =>
    k.endsWith("|ar"),
  ).length;

  return (
    <div className="space-y-4">
      {/* Arabic-first note */}
      <div
        className="rounded-md border border-primary/30 bg-primary/5 p-3 text-sm text-text"
        dir="rtl"
      >
        <p className="flex items-center gap-2 font-medium">
          <Sparkles className="h-4 w-4 text-primary" />
          {t("arabicSourceTitle")}
        </p>
        <p className="mt-1 text-xs text-text-muted">
          {t("arabicSourceBody")}
        </p>
      </div>

      {/* Search + actions toolbar */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex-1 sm:max-w-md">
          <Input
            placeholder={t("searchPlaceholder")}
            value={query}
            onChange={(e) => {
              setQuery(e.target.value);
              setPage(1);
            }}
            iconStart={<Search className="h-4 w-4" />}
          />
        </div>
        <div className="flex flex-wrap items-center gap-2">
          {pendingCount > 0 && (
            <Badge tone="warning">
              {t("pendingChanges", { count: pendingCount })}
            </Badge>
          )}
          <Button
            type="button"
            variant="outline"
            onClick={autoTranslateAll}
            loading={translating}
            iconStart={<Languages className="h-4 w-4" />}
          >
            {arabicEditCount > 0
              ? t("translateFromArabicEdits", { count: arabicEditCount })
              : t("translateMissing")}
          </Button>
          <Button
            onClick={save}
            disabled={pendingCount === 0}
            loading={pending}
            iconStart={<Save className="h-4 w-4" />}
          >
            {t("save")}
          </Button>
        </div>
      </div>

      {/* Status strips */}
      {status === "ok" && (
        <div className="flex items-center gap-2 rounded-md bg-success/10 px-4 py-2 text-success">
          <CheckCircle2 className="h-4 w-4" />
          <span>{t("savedOk")}</span>
        </div>
      )}
      {status === "translated" && (
        <div className="flex items-center gap-2 rounded-md bg-primary/10 px-4 py-2 text-primary">
          <Languages className="h-4 w-4" />
          <span>{t("translatedOk")}</span>
        </div>
      )}
      {status === "fail" && (
        <div className="flex items-center gap-2 rounded-md bg-danger/10 px-4 py-2 text-danger">
          <AlertCircle className="h-4 w-4" />
          <span>{errorMsg ? t(errorMsg.replace("admin.translations.", "")) : t("savedFail")}</span>
        </div>
      )}

      {/* Stats line */}
      <p className="text-xs text-text-muted">
        {t("counts", { shown: visible.length, total: filtered.length })}
      </p>

      {/* Editor table */}
      <div className="overflow-x-auto rounded-lg border border-border bg-surface">
        <table className="w-full text-sm">
          <thead className="bg-surface-muted text-xs uppercase tracking-wider text-text-muted">
            <tr>
              <th className="px-3 py-2 text-start">{t("keyHeader")}</th>
              {locales.map((loc) => (
                <th key={loc} className="px-3 py-2 text-start min-w-[180px]">
                  {localeNames[loc]}
                </th>
              ))}
              <th className="px-3 py-2 text-start">{t("actions")}</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {visible.map((row) => (
              <tr key={row.key} className="hover:bg-surface-muted/40">
                <td className="px-3 py-2 align-top">
                  <p className="font-mono text-xs text-text-muted break-all" dir="ltr">
                    {row.key}
                  </p>
                </td>
                {locales.map((loc) => {
                  const customised = isCustomised(row, loc);
                  return (
                    <td key={loc} className="px-3 py-2 align-top">
                      <div className="flex flex-col gap-1">
                        <textarea
                          value={valueFor(row, loc)}
                          onChange={(e) => editKey(row.key, loc, e.target.value)}
                          rows={2}
                          dir={loc === "ar" || loc === "ur" ? "rtl" : "ltr"}
                          className={`min-h-[44px] w-full resize-y rounded-md border px-2 py-1.5 text-sm outline-none focus:border-primary ${
                            customised
                              ? "border-primary/50 bg-primary/5"
                              : "border-border bg-surface"
                          }`}
                        />
                        {customised && (
                          <span className="text-[10px] text-primary">
                            {t("customised")}
                          </span>
                        )}
                      </div>
                    </td>
                  );
                })}
                <td className="px-3 py-2 align-top">
                  <button
                    type="button"
                    onClick={() => revertRow(row)}
                    title={t("revertTooltip")}
                    className="inline-flex h-8 w-8 items-center justify-center rounded-md text-text-muted hover:bg-surface-muted hover:text-text"
                  >
                    <RotateCcw className="h-3.5 w-3.5" />
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      <div className="flex items-center justify-between">
        <Button
          variant="outline"
          size="sm"
          disabled={page <= 1}
          onClick={() => setPage((p) => Math.max(1, p - 1))}
        >
          {t("prev")}
        </Button>
        <span className="text-sm text-text-muted">
          {t("page", { current: page, total: totalPages })}
        </span>
        <Button
          variant="outline"
          size="sm"
          disabled={page >= totalPages}
          onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
        >
          {t("next")}
        </Button>
      </div>
    </div>
  );
}
