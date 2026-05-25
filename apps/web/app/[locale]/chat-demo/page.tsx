import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container } from "@syanah/ui";
import { ChatThread } from "@/features/chat/components/chat-thread";
import { type Locale } from "@/i18n/locales";

export default async function ChatDemoPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations("chatDemo");

  return (
    <Container className="py-10">
      <h1 className="mb-2 text-2xl font-bold text-text">{t("title")}</h1>
      <p className="mb-6 text-text-muted">{t("subtitle")}</p>
      <ChatThread />
    </Container>
  );
}
