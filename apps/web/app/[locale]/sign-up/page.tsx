import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardHeader, CardTitle, CardBody } from "@syanah/ui";
import { SignUpForm } from "@/features/auth/components/sign-up-form";
import { type Locale } from "@/i18n/locales";
import { Link } from "@/i18n/navigation";

export default async function SignUpPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const nav = await getTranslations("nav");
  const auth = await getTranslations("auth");

  return (
    <Container className="py-16">
      <div className="mx-auto max-w-md">
        <Card>
          <CardHeader>
            <CardTitle>{nav("signUp")}</CardTitle>
          </CardHeader>
          <CardBody>
            <SignUpForm locale={locale as Locale} />
            <p className="mt-6 text-center text-sm text-text-muted">
              {auth("signInPrompt")}{" "}
              <Link href="/sign-in" className="font-medium text-primary hover:underline">
                {nav("signIn")}
              </Link>
            </p>
          </CardBody>
        </Card>
      </div>
    </Container>
  );
}
