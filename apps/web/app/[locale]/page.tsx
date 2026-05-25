import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { Hero } from "@/components/sections/hero";
import { Categories } from "@/components/sections/categories";
import { HowItWorks } from "@/components/sections/how-it-works";
import { ProvidersCta } from "@/components/sections/providers-cta";
import { type Locale } from "@/i18n/locales";

export default async function HomePage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const t = await getTranslations();
  void t;

  return (
    <>
      <Hero />
      <Categories locale={locale as Locale} />
      <HowItWorks />
      <ProvidersCta />
    </>
  );
}
