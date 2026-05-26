import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "Syanah",
    template: "%s · Syanah",
  },
  description: "خدمات الصيانة الموثوقة في المملكة العربية السعودية · Trusted maintenance services across Saudi Arabia.",
  applicationName: "Syanah",
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "Syanah",
  },
  formatDetection: {
    telephone: false,
  },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#faf6ef" },
    { media: "(prefers-color-scheme: dark)", color: "#0a2540" },
  ],
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return children;
}
