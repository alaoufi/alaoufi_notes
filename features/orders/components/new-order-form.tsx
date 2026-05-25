"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Button, Input, Card, CardHeader, CardTitle, CardBody } from "@syanah/ui";
import { LocationPicker } from "@/components/map/location-picker";
import { CategoryIcon } from "@/components/category-icon";
import type { Category, City } from "@/lib/catalog/types";
import { localized } from "@/lib/catalog/types";
import type { Locale } from "@/i18n/locales";

type Step = 1 | 2 | 3 | 4;

export function NewOrderForm({
  categories,
  cities,
  locale,
}: {
  categories: Category[];
  cities: City[];
  locale: Locale;
}) {
  const t = useTranslations("orders.new");
  const common = useTranslations("common");
  const [step, setStep] = useState<Step>(1);
  const [categorySlug, setCategorySlug] = useState<string | null>(null);
  const [citySlug, setCitySlug] = useState<string | null>(null);
  const [address, setAddress] = useState("");
  const [location, setLocation] = useState<{ lat: number; lng: number } | null>(null);
  const [whenChoice, setWhenChoice] = useState<"now" | "scheduled">("now");
  const [scheduledAt, setScheduledAt] = useState<string>("");
  const [notes, setNotes] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  const cat = categories.find((c) => c.slug === categorySlug);
  const city = cities.find((c) => c.slug === citySlug);

  function next() {
    setStep((s) => Math.min(4, s + 1) as Step);
  }
  function back() {
    setStep((s) => Math.max(1, s - 1) as Step);
  }

  async function submit() {
    setSubmitting(true);
    // Wire to server action `createOrderAction` once Supabase env is set.
    // The form is fully validated client-side here; the server will re-validate.
    await new Promise((r) => setTimeout(r, 600));
    setSubmitting(false);
    setSubmitted(true);
  }

  if (submitted) {
    return (
      <Card>
        <CardBody className="space-y-3 py-12 text-center">
          <p className="text-lg font-semibold text-text">{t("submittedTitle")}</p>
          <p className="text-text-muted">{t("submittedBody")}</p>
        </CardBody>
      </Card>
    );
  }

  return (
    <div className="space-y-6">
      <ol className="flex items-center gap-2 text-sm text-text-muted">
        {[1, 2, 3, 4].map((n) => (
          <li
            key={n}
            className={`flex items-center gap-2 ${n === step ? "text-text font-semibold" : ""}`}
          >
            <span
              className={`grid h-6 w-6 place-items-center rounded-pill text-xs ${
                n <= step ? "bg-primary text-primary-contrast" : "bg-surface-muted"
              }`}
            >
              {n}
            </span>
            <span>{t(`steps.${n}`)}</span>
            {n < 4 && <span className="mx-1">›</span>}
          </li>
        ))}
      </ol>

      {step === 1 && (
        <Card>
          <CardHeader><CardTitle>{t("pickCategory")}</CardTitle></CardHeader>
          <CardBody>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
              {categories.map((c) => (
                <button
                  key={c.slug}
                  type="button"
                  onClick={() => setCategorySlug(c.slug)}
                  className={`flex flex-col items-center gap-2 rounded-md border p-3 text-sm transition-colors ${
                    categorySlug === c.slug
                      ? "border-primary bg-primary/5 text-primary"
                      : "border-border bg-surface text-text hover:bg-surface-muted"
                  }`}
                >
                  <CategoryIcon iconKey={c.icon_key} className="h-6 w-6" />
                  <span>{localized(c.name, locale)}</span>
                </button>
              ))}
            </div>
          </CardBody>
        </Card>
      )}

      {step === 2 && (
        <Card>
          <CardHeader><CardTitle>{t("pickLocation")}</CardTitle></CardHeader>
          <CardBody className="space-y-4">
            <Input
              label={t("addressLabel")}
              placeholder={t("addressPlaceholder")}
              value={address}
              onChange={(e) => setAddress(e.target.value)}
            />
            <div>
              <label className="mb-1.5 block text-sm font-medium text-text">{t("cityLabel")}</label>
              <select
                value={citySlug ?? ""}
                onChange={(e) => setCitySlug(e.target.value || null)}
                className="h-11 w-full rounded-md border border-border bg-surface px-3 text-text outline-none focus:border-primary"
              >
                <option value="">{t("cityPlaceholder")}</option>
                {cities.map((c) => (
                  <option key={c.slug} value={c.slug}>
                    {localized(c.name, locale)}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="mb-1.5 block text-sm font-medium text-text">{t("pinLabel")}</label>
              <LocationPicker
                height={300}
                onChange={(p) => setLocation(p)}
              />
              {location && (
                <p className="mt-2 text-xs text-text-muted">
                  {t("pinSelected")}: {location.lat.toFixed(4)}, {location.lng.toFixed(4)}
                </p>
              )}
            </div>
          </CardBody>
        </Card>
      )}

      {step === 3 && (
        <Card>
          <CardHeader><CardTitle>{t("pickWhen")}</CardTitle></CardHeader>
          <CardBody className="space-y-4">
            <div className="grid grid-cols-2 gap-3">
              {(["now", "scheduled"] as const).map((w) => (
                <button
                  key={w}
                  type="button"
                  onClick={() => setWhenChoice(w)}
                  className={`rounded-md border p-4 text-start transition-colors ${
                    whenChoice === w
                      ? "border-primary bg-primary/5"
                      : "border-border bg-surface hover:bg-surface-muted"
                  }`}
                >
                  <p className="font-semibold text-text">{t(`when.${w}.title`)}</p>
                  <p className="mt-1 text-sm text-text-muted">{t(`when.${w}.body`)}</p>
                </button>
              ))}
            </div>
            {whenChoice === "scheduled" && (
              <Input
                type="datetime-local"
                label={t("scheduledAtLabel")}
                value={scheduledAt}
                onChange={(e) => setScheduledAt(e.target.value)}
              />
            )}
            <Input
              label={t("notesLabel")}
              hint={t("notesHint")}
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
            />
          </CardBody>
        </Card>
      )}

      {step === 4 && (
        <Card>
          <CardHeader><CardTitle>{t("review")}</CardTitle></CardHeader>
          <CardBody className="space-y-3">
            <Row label={t("pickCategory")} value={cat ? localized(cat.name, locale) : "—"} />
            <Row label={t("cityLabel")} value={city ? localized(city.name, locale) : "—"} />
            <Row label={t("addressLabel")} value={address || "—"} />
            <Row
              label={t("pinLabel")}
              value={
                location
                  ? `${location.lat.toFixed(4)}, ${location.lng.toFixed(4)}`
                  : "—"
              }
            />
            <Row
              label={t("pickWhen")}
              value={whenChoice === "now" ? t("when.now.title") : scheduledAt || "—"}
            />
            {notes && <Row label={t("notesLabel")} value={notes} />}
          </CardBody>
        </Card>
      )}

      <div className="flex items-center justify-between">
        <Button variant="outline" onClick={back} disabled={step === 1 || submitting}>
          {common("back")}
        </Button>
        {step < 4 ? (
          <Button
            onClick={next}
            disabled={
              (step === 1 && !categorySlug) ||
              (step === 2 && (!citySlug || !address || !location)) ||
              (step === 3 && whenChoice === "scheduled" && !scheduledAt)
            }
          >
            {common("next")}
          </Button>
        ) : (
          <Button onClick={submit} loading={submitting}>
            {t("submit")}
          </Button>
        )}
      </div>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-0.5">
      <span className="text-xs text-text-muted">{label}</span>
      <span className="text-text">{value}</span>
    </div>
  );
}
