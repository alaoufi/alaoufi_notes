#!/usr/bin/env node
/**
 * Pre-flight check before deploying.
 * Usage:  node scripts/check-env.mjs
 *
 * Reads from process.env directly (Vercel injects them at build/runtime; locally
 * the user should `source .env.local` or the script will read what's available).
 * Reports missing keys grouped by impact so it's obvious what breaks without them.
 */

const groups = [
  {
    name: "Supabase (REQUIRED — auth, DB, storage all fail without these)",
    keys: [
      "NEXT_PUBLIC_SUPABASE_URL",
      "NEXT_PUBLIC_SUPABASE_ANON_KEY",
      "SUPABASE_SERVICE_ROLE_KEY",
    ],
    required: true,
  },
  {
    name: "App basics (recommended)",
    keys: ["NEXT_PUBLIC_APP_URL", "NEXT_PUBLIC_DEFAULT_LOCALE"],
    required: false,
  },
  {
    name: "Google Maps (location picker + tracking)",
    keys: ["NEXT_PUBLIC_GOOGLE_MAPS_API_KEY", "GOOGLE_MAPS_SERVER_KEY"],
    required: false,
  },
  {
    name: "Translation (admin CMS auto-translate)",
    keys: ["GOOGLE_TRANSLATE_API_KEY"],
    required: false,
  },
];

const missing = [];
const present = [];

for (const g of groups) {
  for (const k of g.keys) {
    const v = process.env[k];
    if (!v || v.length === 0 || v.startsWith("ey...") || v === "<set me>") {
      missing.push({ group: g.name, key: k, required: g.required });
    } else {
      present.push({ group: g.name, key: k });
    }
  }
}

const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const DIM = "\x1b[2m";
const RESET = "\x1b[0m";

console.log("");
console.log("Syanah · environment check");
console.log("==========================");
console.log("");

for (const g of groups) {
  console.log(`${DIM}${g.name}${RESET}`);
  for (const k of g.keys) {
    const ok = present.find((p) => p.key === k);
    const symbol = ok ? `${GREEN}✓${RESET}` : g.required ? `${RED}✗${RESET}` : `${YELLOW}!${RESET}`;
    console.log(`  ${symbol} ${k}`);
  }
  console.log("");
}

const requiredMissing = missing.filter((m) => m.required);
if (requiredMissing.length > 0) {
  console.log(`${RED}FAIL${RESET} — ${requiredMissing.length} required key${requiredMissing.length === 1 ? "" : "s"} missing.`);
  console.log("");
  console.log("Add them to Vercel → Settings → Environment Variables, or to a");
  console.log("local .env.local if running locally. See supabase/SETUP_GUIDE.md.");
  process.exit(1);
}

const optionalMissing = missing.filter((m) => !m.required);
if (optionalMissing.length > 0) {
  console.log(`${YELLOW}OK${RESET} — required keys present; ${optionalMissing.length} optional key${optionalMissing.length === 1 ? "" : "s"} missing.`);
} else {
  console.log(`${GREEN}OK${RESET} — every configured key present.`);
}
console.log("");
