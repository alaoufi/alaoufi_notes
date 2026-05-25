import { NextIntlClientProvider } from "next-intl";
import { getMessages, setRequestLocale } from "next-intl/server";
import { notFound } from "next/navigation";
import { cookies } from "next/headers";
import { locales, getDirection, type Locale } from "@/i18n/locales";
import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }));
}

export default async function LocaleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale: localeParam } = await params;
  if (!locales.includes(localeParam as Locale)) notFound();

  const locale = localeParam as Locale;
  setRequestLocale(locale);

  const messages = await getMessages();
  const dir = getDirection(locale);

  const cookieStore = await cookies();
  const themeCookie = cookieStore.get("syanah_theme")?.value;
  const theme = themeCookie === "pink" ? "pink" : "soft-blue";

  return (
    <html lang={locale} dir={dir} data-theme={theme} suppressHydrationWarning>
      <body className="min-h-dvh flex flex-col">
        <NextIntlClientProvider locale={locale} messages={messages} timeZone="Asia/Riyadh">
          <SiteHeader locale={locale} theme={theme} />
          <main className="flex-1">{children}</main>
          <SiteFooter />
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
