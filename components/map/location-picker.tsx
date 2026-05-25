"use client";

import { useState } from "react";
import { APIProvider, Map, AdvancedMarker, Pin } from "@vis.gl/react-google-maps";
import { getGoogleMapsApiKey } from "./map-env";
import { MapFallback } from "./map-fallback";

const RIYADH = { lat: 24.7136, lng: 46.6753 };

export function LocationPicker({
  height = 360,
  defaultCenter = RIYADH,
  onChange,
}: {
  height?: number;
  defaultCenter?: { lat: number; lng: number };
  onChange?: (loc: { lat: number; lng: number }) => void;
}) {
  const apiKey = getGoogleMapsApiKey();
  const [pos, setPos] = useState(defaultCenter);

  if (!apiKey) {
    return <MapFallback height={height} />;
  }

  return (
    <div style={{ height }} className="overflow-hidden rounded-lg border border-border">
      <APIProvider apiKey={apiKey}>
        <Map
          mapId="syanah-picker"
          defaultCenter={defaultCenter}
          defaultZoom={12}
          gestureHandling="greedy"
          disableDefaultUI={false}
          onClick={(e) => {
            const lat = e.detail.latLng?.lat;
            const lng = e.detail.latLng?.lng;
            if (lat != null && lng != null) {
              const next = { lat, lng };
              setPos(next);
              onChange?.(next);
            }
          }}
        >
          <AdvancedMarker position={pos}>
            <Pin background="#1f6feb" borderColor="#ffffff" glyphColor="#ffffff" />
          </AdvancedMarker>
        </Map>
      </APIProvider>
    </div>
  );
}
