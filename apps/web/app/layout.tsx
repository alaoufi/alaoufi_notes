import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "Syanah",
    template: "%s · Syanah",
  },
  description: "Trusted maintenance services across Saudi Arabia.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return children;
}
