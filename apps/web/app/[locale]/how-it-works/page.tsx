import { setRequestLocale } from "next-intl/server";
import { HowItWorks } from "@/components/sections/how-it-works";
import { type Locale } from "@/i18n/locales";

export default async function HowItWorksPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  return <HowItWorks />;
}
