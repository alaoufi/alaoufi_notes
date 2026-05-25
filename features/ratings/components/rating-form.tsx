"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Button } from "@syanah/ui";
import { StarRating } from "./star-rating";

export function RatingForm({
  onSubmit,
}: {
  onSubmit?: (score: number, comment: string) => Promise<void> | void;
}) {
  const t = useTranslations("ratings");
  const [score, setScore] = useState(0);
  const [comment, setComment] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (score === 0) return;
    setSubmitting(true);
    await onSubmit?.(score, comment);
    setSubmitting(false);
    setDone(true);
  }

  if (done) {
    return (
      <div className="rounded-md border border-success/40 bg-success/10 p-4 text-success">
        {t("thanks")}
      </div>
    );
  }

  return (
    <form onSubmit={submit} className="space-y-4">
      <div>
        <p className="mb-2 text-sm font-medium text-text">{t("scorePrompt")}</p>
        <StarRating value={score} onChange={setScore} />
      </div>
      <div>
        <label className="mb-1.5 block text-sm font-medium text-text">{t("commentLabel")}</label>
        <textarea
          value={comment}
          onChange={(e) => setComment(e.target.value)}
          rows={4}
          maxLength={2000}
          placeholder={t("commentPlaceholder")}
          className="w-full rounded-md border border-border bg-surface p-3 text-text outline-none focus:border-primary"
        />
        <p className="mt-1 text-xs text-text-muted">{comment.length} / 2000</p>
      </div>
      <Button type="submit" disabled={score === 0} loading={submitting}>
        {t("submit")}
      </Button>
    </form>
  );
}
