"use client";

import { useState, useTransition } from "react";
import { useTranslations } from "next-intl";
import { Button, Input } from "@syanah/ui";
import { signUpAction } from "../server/sign-up";
import { useRouter } from "@/i18n/navigation";
import type { Locale } from "@/i18n/locales";

type Role = "requester" | "provider";

export function SignUpForm({ locale }: { locale: Locale }) {
  const t = useTranslations("auth");
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [role, setRole] = useState<Role>("requester");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);

  function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setErrors({});
    setFormError(null);
    const fd = new FormData(event.currentTarget);
    const payload = {
      fullName: String(fd.get("fullName") ?? ""),
      email: String(fd.get("email") ?? ""),
      phone: String(fd.get("phone") ?? ""),
      password: String(fd.get("password") ?? ""),
      role,
      locale,
    };
    startTransition(async () => {
      try {
        const res = await signUpAction(payload);
        if (!res.ok) {
          setErrors(res.fieldErrors ?? {});
          if (res.errorKey) setFormError(res.errorKey);
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
    <form onSubmit={onSubmit} className="flex flex-col gap-4">
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
        name="fullName"
        label={t("fields.fullName")}
        placeholder={t("placeholders.fullName")}
        error={errors.fullName ? t(errors.fullName) : undefined}
        required
        autoComplete="name"
      />
      <Input
        name="email"
        type="email"
        label={t("fields.email")}
        placeholder="you@example.com"
        error={errors.email ? t(errors.email) : undefined}
        required
        autoComplete="email"
      />
      <Input
        name="phone"
        type="tel"
        label={t("fields.phone")}
        placeholder="+9665XXXXXXXX"
        error={errors.phone ? t(errors.phone) : undefined}
        required
        autoComplete="tel"
        dir="ltr"
      />
      <Input
        name="password"
        type="password"
        label={t("fields.password")}
        error={errors.password ? t(errors.password) : undefined}
        hint={t("hints.passwordPolicy")}
        required
        autoComplete="new-password"
      />

      {formError && (
        <p role="alert" className="text-sm text-danger">
          {t(formError)}
        </p>
      )}

      <Button type="submit" size="lg" loading={pending} fullWidth>
        {t("submit.signUp")}
      </Button>
    </form>
  );
}
