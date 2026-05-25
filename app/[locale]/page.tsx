import { setRequestLocale } from "next-intl/server";
import { Hero } from "@/components/sections/hero";
import { Categories } from "@/components/sections/categories";
import { HowItWorks } from "@/components/sections/how-it-works";
import { Trust } from "@/components/sections/trust";
import { Testimonials } from "@/components/sections/testimonials";
import { ProvidersCta } from "@/components/sections/providers-cta";
import { type Locale } from "@/i18n/locales";

export default async function HomePage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);

  return (
    <>
      <Hero />
      <Categories locale={locale as Locale} />
      <Trust />
      <HowItWorks />
      <Testimonials />
      <ProvidersCta />
    </>
  );
}
