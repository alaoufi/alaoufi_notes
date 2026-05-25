"use client";

import { useState, useTransition } from "react";
import { useTranslations } from "next-intl";
import { Button, Input } from "@syanah/ui";
import { signInAction } from "../server/sign-in";
import { useRouter } from "@/i18n/navigation";
import { User, Lock } from "lucide-react";

export function SignInForm({ returnTo }: { returnTo?: string }) {
  const t = useTranslations("auth");
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [handle, setHandle] = useState("");
  const [password, setPassword] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);

  function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setErrors({});
    setFormError(null);
    startTransition(async () => {
      const res = await signInAction({ handle, password });
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
        name="handle"
        label={t("fields.handle")}
        placeholder={t("placeholders.handle")}
        value={handle}
        onChange={(e) => setHandle(e.target.value)}
        error={errors.handle ? t(errors.handle) : undefined}
        hint={t("hints.handleHint")}
        required
        autoComplete="username"
        iconStart={<User className="h-4 w-4" />}
        dir="ltr"
      />
      <Input
        name="password"
        type="password"
        label={t("fields.password")}
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        error={errors.password ? t(errors.password) : undefined}
        required
        autoComplete="current-password"
        iconStart={<Lock className="h-4 w-4" />}
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
