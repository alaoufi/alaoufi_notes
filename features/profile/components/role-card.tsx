"use client";

import { useState, useTransition } from "react";
import { useTranslations } from "next-intl";
import { Button } from "@syanah/ui";
import { Briefcase, User as UserIcon, Check } from "lucide-react";
import {
  setActiveRoleAction,
  toggleSecondaryRoleAction,
} from "../server/role-actions";

type Role = "requester" | "provider";

interface Props {
  roles: Role[];
  activeRole: Role;
}

export function RoleCard({ roles, activeRole }: Props) {
  const t = useTranslations("profile");
  const authT = useTranslations("auth");
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [localRoles, setLocalRoles] = useState<Role[]>(roles);
  const [localActive, setLocalActive] = useState<Role>(activeRole);

  function switchActive(r: Role) {
    if (!localRoles.includes(r) || r === localActive) return;
    setError(null);
    setLocalActive(r);
    startTransition(async () => {
      const res = await setActiveRoleAction(r);
      if (!res.ok) {
        setLocalActive(activeRole);
        setError(res.errorKey ? authT(res.errorKey.replace("auth.", "")) : t("errors.updateFailed"));
      }
    });
  }

  function toggleSecondary(r: Role) {
    setError(null);
    const has = localRoles.includes(r);
    const next = has ? localRoles.filter((x) => x !== r) : [...localRoles, r];
    if (next.length === 0) {
      setError(t("errors.cantRemoveLastRole"));
      return;
    }
    setLocalRoles(next);
    if (has && r === localActive) setLocalActive(next[0]);
    startTransition(async () => {
      const res = await toggleSecondaryRoleAction(r);
      if (!res.ok) {
        setLocalRoles(roles);
        setLocalActive(activeRole);
        setError(t("errors.updateFailed"));
      }
    });
  }

  return (
    <div className="space-y-4">
      <p className="text-sm text-text-muted">{t("roleCardIntro")}</p>

      <div className="grid grid-cols-2 gap-3">
        {(["requester", "provider"] as const).map((r) => {
          const has = localRoles.includes(r);
          const active = r === localActive;
          return (
            <button
              key={r}
              type="button"
              onClick={() => toggleSecondary(r)}
              disabled={pending}
              aria-pressed={has}
              className={`relative rounded-md border p-4 text-start transition-colors ${
                has
                  ? "border-primary bg-primary/5"
                  : "border-border bg-surface hover:bg-surface-muted"
              } disabled:opacity-60`}
            >
              {has && (
                <Check className="absolute end-2 top-2 h-4 w-4 text-primary" />
              )}
              <div className="flex items-center gap-2">
                {r === "provider" ? (
                  <Briefcase className="h-4 w-4 text-text-muted" />
                ) : (
                  <UserIcon className="h-4 w-4 text-text-muted" />
                )}
                <p className="text-sm font-medium text-text">{authT(`roles.${r}`)}</p>
              </div>
              <p className="mt-1 text-xs text-text-muted">{authT(`rolesHint.${r}`)}</p>
              {active && (
                <span className="mt-2 inline-block rounded-pill bg-accent/10 px-2 py-0.5 text-xs font-medium text-accent">
                  {t("active")}
                </span>
              )}
            </button>
          );
        })}
      </div>

      {localRoles.length > 1 && (
        <div>
          <p className="mb-2 text-sm font-medium text-text">{t("activeRoleSwitchLabel")}</p>
          <div className="grid grid-cols-2 gap-2 rounded-md border border-border p-1">
            {localRoles.map((r) => (
              <Button
                key={r}
                type="button"
                size="sm"
                variant={r === localActive ? "primary" : "ghost"}
                onClick={() => switchActive(r)}
                disabled={pending}
              >
                {authT(`roles.${r}`)}
              </Button>
            ))}
          </div>
          <p className="mt-2 text-xs text-text-muted">{t("activeRoleSwitchHint")}</p>
        </div>
      )}

      {error && <p className="text-sm text-danger">{error}</p>}
    </div>
  );
}
