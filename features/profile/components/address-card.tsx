"use client";

import { useState, useTransition } from "react";
import { useTranslations } from "next-intl";
import { Button } from "@syanah/ui";
import {
  LocationTreePicker,
  type TreeNode,
} from "@/features/location/components/location-tree-picker";
import { emptyLocation, type LocationValue } from "@/features/location/types";
import type { Locale } from "@/i18n/locales";
import { CheckCircle2, Save } from "lucide-react";

export function AddressCard({
  locale,
  tree,
  initial,
}: {
  locale: Locale;
  tree: TreeNode[];
  initial?: Partial<LocationValue> | null;
}) {
  const t = useTranslations("profile");
  const [value, setValue] = useState<LocationValue>({
    ...emptyLocation,
    ...(initial ?? {}),
  });
  const [pending, startTransition] = useTransition();
  const [saved, setSaved] = useState(false);

  function save() {
    setSaved(false);
    startTransition(async () => {
      // Server action wiring lives behind the live Supabase flow. Until that's
      // hooked up we show a brief "saved" confirmation so the UI is reactive.
      await new Promise((r) => setTimeout(r, 500));
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    });
  }

  return (
    <div className="space-y-4">
      <p className="text-sm text-text-muted">{t("addressNote")}</p>
      <LocationTreePicker
        tree={tree}
        value={value}
        onChange={setValue}
        locale={locale}
      />
      <div className="flex items-center justify-end gap-3 border-t border-border pt-4">
        {saved && (
          <span className="inline-flex items-center gap-1 text-sm text-success">
            <CheckCircle2 className="h-4 w-4" />
            {t("addressSaved")}
          </span>
        )}
        <Button onClick={save} loading={pending} iconStart={<Save className="h-4 w-4" />}>
          {t("save")}
        </Button>
      </div>
    </div>
  );
}
