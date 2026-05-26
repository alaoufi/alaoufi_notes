import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Button } from "@syanah/ui";
import { Link } from "@/i18n/navigation";
import { type Locale } from "@/i18n/locales";
import { WifiOff, RefreshCw } from "lucide-react";

export const dynamic = "force-static";

export default async function OfflinePage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("offline");

  return (
    <Container className="flex min-h-[60vh] flex-col items-center justify-center gap-4 py-16 text-center">
      <span className="grid h-16 w-16 place-items-center rounded-pill bg-surface-muted text-text-muted">
        <WifiOff className="h-8 w-8" />
      </span>
      <h1 className="text-2xl font-bold text-text">{t("title")}</h1>
      <p className="max-w-md text-text-muted">{t("body")}</p>
      <Link href="/">
        <Button iconEnd={<RefreshCw className="h-4 w-4" />}>{t("retry")}</Button>
      </Link>
    </Container>
  );
}
