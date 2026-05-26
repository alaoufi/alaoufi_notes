import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Syanah · صيانة",
    short_name: "Syanah",
    description: "خدمات الصيانة الموثوقة في المملكة العربية السعودية",
    start_url: "/",
    display: "standalone",
    background_color: "#faf6ef",
    theme_color: "#0a2540",
    orientation: "portrait",
    lang: "ar",
    dir: "rtl",
    categories: ["business", "lifestyle", "utilities"],
    icons: [
      {
        src: "/icon.svg",
        sizes: "any",
        type: "image/svg+xml",
        purpose: "any",
      },
      {
        src: "/apple-icon.svg",
        sizes: "180x180",
        type: "image/svg+xml",
        purpose: "maskable",
      },
    ],
    shortcuts: [
      {
        name: "طلباتي",
        short_name: "الطلبات",
        url: "/ar/orders",
      },
      {
        name: "تصفّح المزوّدين",
        short_name: "المزوّدون",
        url: "/ar/providers",
      },
    ],
  };
}
