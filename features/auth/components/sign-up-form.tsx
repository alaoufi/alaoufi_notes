"use client";

import { useState, useTransition } from "react";
import { useTranslations } from "next-intl";
import { Button, Input } from "@syanah/ui";
import { signUpAction } from "../server/sign-up";
import { useRouter } from "@/i18n/navigation";
import type { Locale } from "@/i18n/locales";
import {
  LocationTreePicker,
  type TreeNode,
} from "@/features/location/components/location-tree-picker";
import { emptyLocation, type LocationValue } from "@/features/location/types";
import { ArrowLeft, ArrowRight } from "lucide-react";

type Role = "requester" | "provider";

export function SignUpForm({
  locale,
  locationTree,
}: {
  locale: Locale;
  locationTree: TreeNode[];
}) {
  const t = useTranslations("auth");
  const common = useTranslations("common");
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [step, setStep] = useState<1 | 2>(1);

  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [role, setRole] = useState<Role>("requester");

  const [location, setLocation] = useState<LocationValue>(emptyLocation);

  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);

  function step1Valid() {
    return (
      fullName.trim().length >= 2 &&
      /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) &&
      /^\+?[1-9]\d{7,14}$/.test(phone) &&
      password.length >= 8 &&
      /[A-Z]/.test(password) &&
      /[a-z]/.test(password) &&
      /[0-9]/.test(password)
    );
  }

  function step2Valid() {
    return (
      Boolean(location.regionSlug) &&
      Boolean(location.governorateSlug) &&
      Boolean(location.citySlug)
    );
  }

  function next() {
    if (step === 1 && step1Valid()) {
      setErrors({});
      setStep(2);
    }
  }

  function submit() {
    setErrors({});
    setFormError(null);
    if (!step2Valid()) {
      setFormError("auth.errors.locationRequired");
      return;
    }
    startTransition(async () => {
      try {
        const res = await signUpAction({
          fullName,
          email,
          phone,
          password,
          role,
          locale,
          regionSlug: location.regionSlug ?? "",
          governorateSlug: location.governorateSlug ?? "",
          citySlug: location.citySlug ?? "",
          districtName: location.districtName,
          street: location.street,
          building: location.building,
          lat: location.lat,
          lng: location.lng,
        });
        if (!res.ok) {
          setErrors(res.fieldErrors ?? {});
          if (res.errorKey) setFormError(res.errorKey);
          if (
            res.fieldErrors &&
            Object.keys(res.fieldErrors).some((k) =>
              ["fullName", "email", "phone", "password"].includes(k),
            )
          ) {
            setStep(1);
          }
          return;
        }
        router.replace("/dashboard");
      } catch (err) {
        const msg = err instanceof Error ? err.message : "auth.errors.unknown";
        setFormError(msg);
      }
    });
  }

  return (
    <div className="space-y-6">
      <ol className="flex items-center gap-2 text-sm text-text-muted">
        {[1, 2].map((n) => (
          <li
            key={n}
            className={`flex items-center gap-2 ${n === step ? "text-text font-semibold" : ""}`}
          >
            <span
              className={`grid h-7 w-7 place-items-center rounded-pill text-xs ${
                n <= step ? "bg-primary text-primary-contrast" : "bg-surface-muted"
              }`}
            >
              {n}
            </span>
            <span>{t(`steps.step${n}`)}</span>
            {n < 2 && <span className="mx-1">›</span>}
          </li>
        ))}
      </ol>

      {step === 1 && (
        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-2 rounded-md border border-border p-1">
            {(["requester", "provider"] as const).map((r) => (
              <button
                key={r}
                type="button"
                onClick={() => setRole(r)}
                className={`rounded-sm px-4 py-2 text-sm font-medium transition-colors ${
                  role === r
                    ? "bg-primary text-primary-contrast shadow-sm"
                    : "text-text-muted hover:text-text"
                }`}
              >
                {t(`roles.${r}`)}
              </button>
            ))}
          </div>

          <Input
            label={t("fields.fullName")}
            placeholder={t("placeholders.fullName")}
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
            error={errors.fullName ? t(errors.fullName) : undefined}
            required
            autoComplete="name"
          />
          <Input
            type="email"
            label={t("fields.email")}
            placeholder="you@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            error={errors.email ? t(errors.email) : undefined}
            required
            autoComplete="email"
          />
          <Input
            type="tel"
            label={t("fields.phone")}
            placeholder="+9665XXXXXXXX"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            error={errors.phone ? t(errors.phone) : undefined}
            required
            autoComplete="tel"
            dir="ltr"
          />
          <Input
            type="password"
            label={t("fields.password")}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            error={errors.password ? t(errors.password) : undefined}
            hint={t("hints.passwordPolicy")}
            required
            autoComplete="new-password"
          />

          <Button
            type="button"
            size="lg"
            fullWidth
            onClick={next}
            disabled={!step1Valid()}
            iconEnd={<ArrowRight className="h-4 w-4 rtl:rotate-180" />}
          >
            {common("next")}
          </Button>
        </div>
      )}

      {step === 2 && (
        <div className="space-y-5">
          <div>
            <p className="mb-1 text-sm font-medium text-text">{t("steps.step2")}</p>
            <p className="text-sm text-text-muted">{t("locationIntro")}</p>
          </div>

          <LocationTreePicker
            tree={locationTree}
            value={location}
            onChange={setLocation}
            locale={locale}
          />

          {formError && (
            <p role="alert" className="text-sm text-danger">
              {t(formError)}
            </p>
          )}

          <div className="flex items-center gap-3">
            <Button
              type="button"
              variant="outline"
              onClick={() => setStep(1)}
              iconStart={<ArrowLeft className="h-4 w-4 rtl:rotate-180" />}
            >
              {common("back")}
            </Button>
            <Button
              type="button"
              size="lg"
              loading={pending}
              disabled={!step2Valid()}
              onClick={submit}
              fullWidth
            >
              {t("submit.signUp")}
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
