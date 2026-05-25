"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Button, Input } from "@syanah/ui";

export function DisputeForm({
  onSubmit,
}: {
  onSubmit?: (reason: string, description: string) => Promise<void> | void;
}) {
  const t = useTranslations("disputes");
  const [reason, setReason] = useState("");
  const [description, setDescription] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (reason.length < 3) return;
    setSubmitting(true);
    await onSubmit?.(reason, description);
    setSubmitting(false);
    setDone(true);
  }

  if (done) {
    return (
      <div className="rounded-md border border-warning/40 bg-warning/10 p-4 text-warning">
        {t("opened")}
      </div>
    );
  }

  return (
    <form onSubmit={submit} className="space-y-4">
      <Input
        label={t("reasonLabel")}
        placeholder={t("reasonPlaceholder")}
        value={reason}
        onChange={(e) => setReason(e.target.value)}
        required
        minLength={3}
        maxLength={200}
      />
      <div>
        <label className="mb-1.5 block text-sm font-medium text-text">
          {t("descriptionLabel")}
        </label>
        <textarea
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          rows={6}
          maxLength={5000}
          placeholder={t("descriptionPlaceholder")}
          className="w-full rounded-md border border-border bg-surface p-3 text-text outline-none focus:border-primary"
        />
        <p className="mt-1 text-xs text-text-muted">
          {t("descriptionHint")} · {description.length} / 5000
        </p>
      </div>
      <Button type="submit" variant="danger" loading={submitting} disabled={reason.length < 3}>
        {t("submit")}
      </Button>
    </form>
  );
}
