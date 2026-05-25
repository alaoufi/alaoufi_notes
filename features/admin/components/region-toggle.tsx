"use client";

import { useState, useTransition } from "react";
import { useTranslations } from "next-intl";
import { setRegionActive, setGovernorateActive } from "../server/toggle-region";

interface BaseProps {
  id?: string;
  initialActive: boolean;
  disabled?: boolean;
}

function Switch({
  active,
  pending,
  disabled,
  onToggle,
  label,
}: {
  active: boolean;
  pending: boolean;
  disabled?: boolean;
  onToggle: () => void;
  label: string;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={active}
      aria-busy={pending || undefined}
      aria-label={label}
      onClick={onToggle}
      disabled={pending || disabled}
      className={`relative inline-flex h-6 w-11 flex-shrink-0 items-center rounded-full transition-colors disabled:opacity-50 ${
        active ? "bg-success" : "bg-border-strong"
      }`}
    >
      <span
        className={`inline-block h-5 w-5 transform rounded-full bg-white shadow transition-transform ${
          active ? "translate-x-5 rtl:-translate-x-5" : "translate-x-0.5 rtl:-translate-x-0.5"
        }`}
      />
    </button>
  );
}

export function RegionToggle({ id, initialActive, disabled }: BaseProps) {
  const t = useTranslations("admin.regions");
  const [active, setActive] = useState(initialActive);
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  function toggle() {
    if (!id) {
      setError(t("errors.noBackend"));
      return;
    }
    setError(null);
    const next = !active;
    setActive(next);  // optimistic
    startTransition(async () => {
      const res = await setRegionActive(id, next);
      if (!res.ok) {
        setActive(!next);
        setError(res.errorKey ? t(res.errorKey.replace("admin.regions.", "")) : t("errors.updateFailed"));
      }
    });
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <Switch
        active={active}
        pending={pending}
        disabled={disabled}
        onToggle={toggle}
        label={t("toggleRegion")}
      />
      {error && <p className="text-xs text-danger">{error}</p>}
    </div>
  );
}

export function GovernorateToggle({ id, initialActive, disabled }: BaseProps) {
  const t = useTranslations("admin.regions");
  const [active, setActive] = useState(initialActive);
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  function toggle() {
    if (!id) {
      setError(t("errors.noBackend"));
      return;
    }
    setError(null);
    const next = !active;
    setActive(next);
    startTransition(async () => {
      const res = await setGovernorateActive(id, next);
      if (!res.ok) {
        setActive(!next);
        setError(res.errorKey ? t(res.errorKey.replace("admin.regions.", "")) : t("errors.updateFailed"));
      }
    });
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <Switch
        active={active}
        pending={pending}
        disabled={disabled}
        onToggle={toggle}
        label={t("toggleGovernorate")}
      />
      {error && <p className="text-xs text-danger">{error}</p>}
    </div>
  );
}
