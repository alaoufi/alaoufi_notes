export function getGoogleMapsApiKey(): string | null {
  const k = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY;
  return k && k.length > 0 ? k : null;
}
