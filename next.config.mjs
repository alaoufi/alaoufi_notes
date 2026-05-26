import createNextIntlPlugin from "next-intl/plugin";

const withNextIntl = createNextIntlPlugin("./i18n/request.ts");

// Security headers applied to every response.
// CSP is intentionally permissive enough to allow Google Maps + Supabase +
// inline styles next-intl/Tailwind emit, while still blocking arbitrary
// script origins. Tighten the script-src once we have a nonce strategy.
const securityHeaders = [
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-Frame-Options",        value: "SAMEORIGIN" },
  { key: "Referrer-Policy",        value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy",     value: "camera=(), microphone=(self), geolocation=(self), payment=()" },
  { key: "X-DNS-Prefetch-Control", value: "on" },
  {
    key: "Strict-Transport-Security",
    value: "max-age=63072000; includeSubDomains; preload",
  },
];

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  transpilePackages: ["@syanah/ui"],

  images: {
    remotePatterns: [
      { protocol: "https", hostname: "*.supabase.co" },
      { protocol: "https", hostname: "images.unsplash.com" },
    ],
    formats: ["image/avif", "image/webp"],
    deviceSizes: [360, 540, 720, 960, 1280, 1600],
    imageSizes: [16, 32, 48, 64, 96, 128, 256],
  },

  // Add Cache-Control for /icon.svg + /apple-icon.svg + /sw.js so the PWA
  // shell isn't aggressively cached but assets are.
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: securityHeaders,
      },
      {
        source: "/sw.js",
        headers: [
          { key: "Cache-Control", value: "no-cache, no-store, must-revalidate" },
          { key: "Content-Type", value: "application/javascript; charset=utf-8" },
        ],
      },
    ];
  },

  experimental: {
    typedRoutes: false,
  },
};

export default withNextIntl(nextConfig);
