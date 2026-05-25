"use client";

import { useState, useTransition } from "react";
import { useTranslations } from "next-intl";
import { Button } from "@syanah/ui";
import { ShieldCheck, ArrowRight, AlertCircle } from "lucide-react";
import { bootstrapAdminAction } from "../server/bootstrap-admin";
import { useRouter } from "@/i18n/navigation";

type Status = "idle" | "loading" | "ok" | "fail";

export function BootstrapAdminButton({ disabled }: { disabled?: boolean }) {
  const t = useTranslations("adminSetup");
  const router = useRouter();
  const [status, setStatus] = useState<Status>("idle");
  const [errorKey, setErrorKey] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function promote() {
    setStatus("loading");
    setErrorKey(null);
    startTransition(async () => {
      const res = await bootstrapAdminAction();
      if (res.ok) {
        setStatus("ok");
        setTimeout(() => router.push("/admin"), 1500);
      } else {
        setStatus("fail");
        setErrorKey(res.errorKey);
      }
    });
  }

  if (status === "ok") {
    return (
      <div className="space-y-3">
        <div className="flex items-center gap-2 rounded-md bg-success/10 px-4 py-3 text-success">
          <ShieldCheck className="h-5 w-5" />
          <span className="font-medium">{t("success")}</span>
        </div>
        <p className="text-sm text-text-muted">{t("redirecting")}</p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <Button
        type="button"
        size="lg"
        onClick={promote}
        loading={pending}
        disabled={disabled}
        fullWidth
        iconStart={<ShieldCheck className="h-5 w-5" />}
        iconEnd={<ArrowRight className="h-4 w-4 rtl:rotate-180" />}
      >
        {t("promoteMe")}
      </Button>
      {status === "fail" && errorKey && (
        <div className="flex items-center gap-2 rounded-md bg-danger/10 px-3 py-2 text-sm text-danger">
          <AlertCircle className="h-4 w-4" />
          <span>{t(errorKey.replace("adminSetup.", ""))}</span>
        </div>
      )}
    </div>
  );
}
