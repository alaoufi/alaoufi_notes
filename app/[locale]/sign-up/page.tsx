import { setRequestLocale, getTranslations } from "next-intl/server";
import { Container, Card, CardHeader, CardTitle, CardBody } from "@syanah/ui";
import { SignUpForm } from "@/features/auth/components/sign-up-form";
import { getActiveLocationTree } from "@/lib/catalog/location-tree";
import { type Locale } from "@/i18n/locales";
import { Link } from "@/i18n/navigation";

export const dynamic = "force-dynamic";

export default async function SignUpPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale as Locale);
  const nav = await getTranslations("nav");
  const auth = await getTranslations("auth");
  const tree = await getActiveLocationTree();

  return (
    <Container className="py-12">
      <div className="mx-auto max-w-2xl">
        <Card>
          <CardHeader>
            <CardTitle>{nav("signUp")}</CardTitle>
          </CardHeader>
          <CardBody>
            <SignUpForm locale={locale as Locale} locationTree={tree} />
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
