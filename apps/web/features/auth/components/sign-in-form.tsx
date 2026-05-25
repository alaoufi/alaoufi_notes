"use client";

import { useState, useTransition } from "react";
import { useTranslations } from "next-intl";
import { Button, Input } from "@syanah/ui";
import { signInAction } from "../server/sign-in";
import { useRouter } from "@/i18n/navigation";

export function SignInForm({ returnTo }: { returnTo?: string }) {
  const t = useTranslations("auth");
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);

  function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setErrors({});
    setFormError(null);
    const fd = new FormData(event.currentTarget);
    const payload = {
      email: String(fd.get("email") ?? ""),
      password: String(fd.get("password") ?? ""),
    };
    startTransition(async () => {
      const res = await signInAction(payload);
      if (!res.ok) {
        setErrors(res.fieldErrors ?? {});
        if (res.errorKey) setFormError(res.errorKey);
        return;
      }
      router.replace(returnTo ?? "/dashboard");
    });
  }

  return (
    <form onSubmit={onSubmit} className="flex flex-col gap-4">
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
        name="password"
        type="password"
        label={t("fields.password")}
        error={errors.password ? t(errors.password) : undefined}
        required
        autoComplete="current-password"
      />

      {formError && (
        <p role="alert" className="text-sm text-danger">
          {t(formError)}
        </p>
      )}

      <Button type="submit" size="lg" loading={pending} fullWidth>
        {t("submit.signIn")}
      </Button>
    </form>
  );
}
