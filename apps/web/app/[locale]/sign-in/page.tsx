import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardHeader, CardTitle, CardBody } from "@syanah/ui";
import { SignInForm } from "@/features/auth/components/sign-in-form";
import { type Locale } from "@/i18n/locales";
import { Link } from "@/i18n/navigation";

export default async function SignInPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ returnTo?: string }>;
}) {
  const { locale } = await params;
  const { returnTo } = await searchParams;
  setRequestLocale(locale as Locale);
  const nav = await getTranslations("nav");
  const auth = await getTranslations("auth");

  return (
    <Container className="py-16">
      <div className="mx-auto max-w-md">
        <Card>
          <CardHeader>
            <CardTitle>{nav("signIn")}</CardTitle>
          </CardHeader>
          <CardBody>
            <SignInForm returnTo={returnTo} />
            <p className="mt-6 text-center text-sm text-text-muted">
              {auth("signUpPrompt")}{" "}
              <Link href="/sign-up" className="font-medium text-primary hover:underline">
                {nav("signUp")}
              </Link>
            </p>
          </CardBody>
        </Card>
      </div>
    </Container>
  );
}
