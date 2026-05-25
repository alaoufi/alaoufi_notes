"use client";

import { useEffect, useState } from "react";
import { APIProvider, Map, AdvancedMarker, Pin } from "@vis.gl/react-google-maps";
import { getGoogleMapsApiKey } from "./map-env";
import { MapFallback } from "./map-fallback";

export interface ProviderPing {
  lat: number;
  lng: number;
  heading?: number | null;
  speedMps?: number | null;
  at: string;
}

export function TrackingMap({
  destination,
  providerPing,
  height = 420,
}: {
  destination: { lat: number; lng: number };
  providerPing: ProviderPing | null;
  height?: number;
}) {
  const apiKey = getGoogleMapsApiKey();
  const [center, setCenter] = useState(destination);

  useEffect(() => {
    if (providerPing) {
      const midLat = (providerPing.lat + destination.lat) / 2;
      const midLng = (providerPing.lng + destination.lng) / 2;
      setCenter({ lat: midLat, lng: midLng });
    } else {
      setCenter(destination);
    }
  }, [providerPing, destination]);

  if (!apiKey) return <MapFallback height={height} />;

  return (
    <div style={{ height }} className="overflow-hidden rounded-lg border border-border">
      <APIProvider apiKey={apiKey}>
        <Map
          mapId="syanah-tracking"
          center={center}
          defaultZoom={13}
          gestureHandling="greedy"
        >
          <AdvancedMarker position={destination}>
            <Pin background="#22c55e" borderColor="#ffffff" glyphColor="#ffffff" />
          </AdvancedMarker>
          {providerPing && (
            <AdvancedMarker position={{ lat: providerPing.lat, lng: providerPing.lng }}>
              <Pin background="#1f6feb" borderColor="#ffffff" glyphColor="#ffffff" />
            </AdvancedMarker>
          )}
        </Map>
      </APIProvider>
    </div>
  );
}
