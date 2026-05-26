"use client";

import { useMemo, useState, useTransition } from "react";
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
import { usernameRegex, phoneRegex } from "../schema";

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
  // Server errors come back as full dotted paths; resolve them at the root.
  const tRoot = useTranslations();
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [step, setStep] = useState<1 | 2>(1);

  const [fullName, setFullName] = useState("");
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [roles, setRoles] = useState<Role[]>(["requester"]);
  const [activeRole, setActiveRole] = useState<Role>("requester");

  const [location, setLocation] = useState<LocationValue>(emptyLocation);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);

  const usernameOk = useMemo(
    () => username === "" || usernameRegex.test(username.toLowerCase()),
    [username],
  );
  const emailOk = useMemo(
    () => email === "" || /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email),
    [email],
  );

  function toggleRole(r: Role) {
    setRoles((cur) => {
      const has = cur.includes(r);
      const next = has ? cur.filter((x) => x !== r) : [...cur, r];
      if (next.length === 0) return cur; // keep at least one
      if (!next.includes(activeRole)) setActiveRole(next[0]);
      return next;
    });
  }

  function step1Valid() {
    return (
      fullName.trim().length >= 2 &&
      phoneRegex.test(phone) &&
      password.length >= 4 &&
      usernameOk &&
      emailOk &&
      roles.length > 0
    );
  }

  function step2Valid() {
    return (
      Boolean(location.regionSlug) &&
      Boolean(location.governorateSlug) &&
      Boolean(location.citySlug)
    );
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
          username: username.toLowerCase(),
          email,
          phone,
          password,
          roles,
          activeRole,
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
              ["fullName", "email", "phone", "password", "username"].includes(k),
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
          <div>
            <p className="mb-2 text-sm font-medium text-text">{t("rolesLabel")}</p>
            <div className="grid grid-cols-2 gap-2">
              {(["requester", "provider"] as const).map((r) => {
                const checked = roles.includes(r);
                return (
                  <button
                    key={r}
                    type="button"
                    onClick={() => toggleRole(r)}
                    aria-pressed={checked}
                    className={`rounded-md border px-4 py-3 text-start text-sm transition-colors ${
                      checked
                        ? "border-primary bg-primary/5 text-primary"
                        : "border-border text-text hover:bg-surface-muted"
                    }`}
                  >
                    <p className="font-medium">{t(`roles.${r}`)}</p>
                    <p className="mt-1 text-xs text-text-muted">{t(`rolesHint.${r}`)}</p>
                  </button>
                );
              })}
            </div>
            <p className="mt-1 text-xs text-text-muted">{t("rolesHint.both")}</p>
          </div>

          {roles.length > 1 && (
            <div>
              <p className="mb-1.5 text-sm font-medium text-text">{t("activeRoleLabel")}</p>
              <div className="grid grid-cols-2 gap-2 rounded-md border border-border p-1">
                {roles.map((r) => (
                  <button
                    key={r}
                    type="button"
                    onClick={() => setActiveRole(r)}
                    className={`rounded-sm px-4 py-2 text-sm font-medium transition-colors ${
                      activeRole === r
                        ? "bg-primary text-primary-contrast shadow-sm"
                        : "text-text-muted hover:text-text"
                    }`}
                  >
                    {t(`roles.${r}`)}
                  </button>
                ))}
              </div>
            </div>
          )}

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
            label={t("fields.phone")}
            placeholder="+9665XXXXXXXX"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            error={errors.phone ? t(errors.phone) : undefined}
            required
            autoComplete="tel"
            type="tel"
            dir="ltr"
            hint={t("hints.phonePrimary")}
          />

          <Input
            label={t("fields.username")}
            placeholder="ahmed_m"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            error={
              errors.username
                ? t(errors.username)
                : !usernameOk
                  ? t("errors.usernameInvalid")
                  : undefined
            }
            hint={t("hints.usernameOptional")}
            autoComplete="username"
            dir="ltr"
          />

          <Input
            label={t("fields.emailOptional")}
            placeholder="you@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            error={
              errors.email
                ? t(errors.email)
                : !emailOk
                  ? t("errors.emailInvalid")
                  : undefined
            }
            type="email"
            autoComplete="email"
            hint={t("hints.emailOptional")}
          />

          <Input
            label={t("fields.password")}
            type="password"
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
            onClick={() => step1Valid() && (setErrors({}), setStep(2))}
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
              {tRoot.has(formError) ? tRoot(formError) : formError}
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
