import { MapPin } from "lucide-react";

export function MapFallback({
  height = 360,
  hint,
}: {
  height?: number;
  hint?: string;
}) {
  return (
    <div
      role="img"
      aria-label="map placeholder"
      className="flex flex-col items-center justify-center gap-2 rounded-lg border border-dashed border-border bg-surface-muted text-text-muted"
      style={{ height }}
    >
      <MapPin className="h-7 w-7" />
      <p className="px-4 text-center text-sm">
        {hint ??
          "Google Maps API key not configured. Add NEXT_PUBLIC_GOOGLE_MAPS_API_KEY to enable maps."}
      </p>
    </div>
  );
}
