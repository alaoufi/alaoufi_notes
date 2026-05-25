import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardHeader, CardTitle, CardBody, Input, Button, Badge } from "@syanah/ui";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import { getCurrentRoles, requireUser } from "@/lib/auth/guard";
import { RoleCard } from "@/features/profile/components/role-card";
import { type Locale } from "@/i18n/locales";
import { Mail, Phone, AtSign } from "lucide-react";

export const dynamic = "force-dynamic";

export default async function ProfilePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("profile");
  const authT = await getTranslations("auth");

  // Pull live user info when possible; otherwise display the demo placeholders.
  let user: {
    email: string | null;
    phone: string | null;
    username: string | null;
    fullName: string | null;
    roles: Array<"requester" | "provider" | "super_admin" | "section_admin">;
    activeRole: "requester" | "provider";
  } = {
    email: "demo@syanah.app",
    phone: "+9665XXXXXXXX",
    username: "demo_user",
    fullName: "ضيف العرض",
    roles: ["requester"],
    activeRole: "requester",
  };

  if (hasSupabaseEnv()) {
    const u = await requireUser(`/${locale}/profile`);
    const roles = await getCurrentRoles();
    user = {
      email: u.email ?? null,
      phone: (u.phone as string | undefined) ?? null,
      username: null, // resolved via a profile read in the live action
      fullName: null,
      roles: (roles.length ? roles : ["requester"]) as typeof user.roles,
      activeRole:
        roles.includes("provider") && roles.includes("requester")
          ? "requester"
          : roles.includes("provider")
            ? "provider"
            : "requester",
    };
  }

  const heldRoles = user.roles.filter(
    (r) => r === "requester" || r === "provider",
  ) as Array<"requester" | "provider">;

  return (
    <Container className="py-10">
      <header className="mb-6">
        <h1 className="text-2xl font-bold text-text">{t("title")}</h1>
        <p className="text-sm text-text-muted">{t("subtitle")}</p>
      </header>

      <div className="grid gap-6 lg:grid-cols-3">
        {/* Login credentials */}
        <Card className="lg:col-span-1">
          <CardHeader>
            <CardTitle>{t("loginCreds")}</CardTitle>
          </CardHeader>
          <CardBody className="space-y-4">
            <p className="text-sm text-text-muted">{t("loginCredsIntro")}</p>

            <div className="space-y-3">
              <CredRow
                icon={<Phone className="h-4 w-4 text-success" />}
                label={t("phone")}
                value={user.phone ?? "—"}
                tone="required"
                requiredLabel={t("required")}
              />
              <CredRow
                icon={<AtSign className="h-4 w-4 text-primary" />}
                label={t("username")}
                value={user.username ?? "—"}
                tone="optional"
                optionalLabel={t("optional")}
              />
              <CredRow
                icon={<Mail className="h-4 w-4 text-info" />}
                label={t("email")}
                value={user.email ?? "—"}
                tone="optional"
                optionalLabel={t("optional")}
              />
            </div>

            <p className="rounded-md border border-dashed border-border p-3 text-xs text-text-muted">
              {t("loginCredsHint")}
            </p>
          </CardBody>
        </Card>

        {/* Personal info */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>{t("personal")}</CardTitle>
          </CardHeader>
          <CardBody className="space-y-4">
            <Input label={t("fullName")} defaultValue={user.fullName ?? ""} placeholder={t("fullNamePlaceholder")} />
            <Input
              label={t("usernameEditable")}
              defaultValue={user.username ?? ""}
              placeholder="ahmed_m"
              dir="ltr"
              hint={authT("hints.usernameOptional")}
            />
            <Input
              label={t("emailEditable")}
              type="email"
              defaultValue={user.email ?? ""}
              hint={authT("hints.emailOptional")}
            />
            <Input
              label={t("phoneEditable")}
              type="tel"
              defaultValue={user.phone ?? ""}
              dir="ltr"
              hint={authT("hints.phonePrimary")}
            />
            <Button>{t("save")}</Button>
          </CardBody>
        </Card>

        {/* Role mode */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>{t("roleMode")}</CardTitle>
          </CardHeader>
          <CardBody>
            <RoleCard roles={heldRoles} activeRole={user.activeRole} />
          </CardBody>
        </Card>

        {/* Address */}
        <Card className="lg:col-span-1">
          <CardHeader>
            <CardTitle>{t("address")}</CardTitle>
          </CardHeader>
          <CardBody className="space-y-3">
            <p className="text-sm text-text-muted">{t("addressNote")}</p>
            <Badge tone="neutral">{t("addressEditNote")}</Badge>
          </CardBody>
        </Card>
      </div>
    </Container>
  );
}

function CredRow({
  icon,
  label,
  value,
  tone,
  requiredLabel,
  optionalLabel,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  tone: "required" | "optional";
  requiredLabel?: string;
  optionalLabel?: string;
}) {
  return (
    <div className="flex items-center justify-between gap-3 rounded-md border border-border bg-surface p-3">
      <div className="flex items-center gap-2">
        <span>{icon}</span>
        <div>
          <p className="text-xs text-text-muted">{label}</p>
          <p className="text-sm font-medium text-text" dir="ltr">
            {value}
          </p>
        </div>
      </div>
      <Badge tone={tone === "required" ? "success" : "neutral"}>
        {tone === "required" ? requiredLabel : optionalLabel}
      </Badge>
    </div>
  );
}
