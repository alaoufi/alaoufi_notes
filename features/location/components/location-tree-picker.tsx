"use client";

import { useEffect, useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { APIProvider, useMapsLibrary } from "@vis.gl/react-google-maps";
import { Input } from "@syanah/ui";
import { LocationPicker } from "@/components/map/location-picker";
import { localized } from "@/lib/catalog/types";
import { getGoogleMapsApiKey } from "@/components/map/map-env";
import type { Locale } from "@/i18n/locales";
import type { LocationValue } from "../types";
import { MapPin, Crosshair, CheckCircle2, AlertCircle } from "lucide-react";

export interface TreeDistrict {
  slug: string;
  name: Record<string, string>;
  lat?: number | null;
  lng?: number | null;
}

export interface TreeCity {
  slug: string;
  name: Record<string, string>;
  districts: TreeDistrict[];
}

export interface TreeNode {
  region: { slug: string; name: Record<string, string> };
  governorates: Array<{
    slug: string;
    name: Record<string, string>;
    cities: TreeCity[];
  }>;
}

type ReverseGeocodeResult = {
  regionSlug: string | null;
  governorateSlug: string | null;
  citySlug: string | null;
  district: string;
};

/**
 * Matches a free-form locality string against the tree by comparing it to both
 * Arabic and English names. Returns the slug of the first match, or null.
 */
function matchSlug(
  candidates: Array<{ slug: string; name: Record<string, string> }>,
  query: string | undefined,
): string | null {
  if (!query) return null;
  const normalised = query.trim().toLowerCase();
  if (!normalised) return null;
  for (const c of candidates) {
    const ar = (c.name.ar ?? "").toLowerCase();
    const en = (c.name.en ?? "").toLowerCase();
    if (
      ar === normalised ||
      en === normalised ||
      ar.includes(normalised) ||
      normalised.includes(ar) ||
      en.includes(normalised) ||
      normalised.includes(en)
    ) {
      return c.slug;
    }
  }
  return null;
}

interface LocationTreePickerProps {
  tree: TreeNode[];
  value: LocationValue;
  onChange: (next: LocationValue) => void;
  locale: Locale;
  showMap?: boolean;
}

export function LocationTreePicker(props: LocationTreePickerProps) {
  const apiKey = getGoogleMapsApiKey();
  // When Maps is available, wrap the picker in APIProvider so the reverse
  // geocoder hook can resolve. The inner LocationPicker reuses the same
  // context. When there's no key, render without APIProvider — the picker
  // still works, just without auto-fill or the map.
  if (apiKey) {
    return (
      <APIProvider apiKey={apiKey}>
        <LocationTreePickerInner {...props} />
      </APIProvider>
    );
  }
  return <LocationTreePickerInner {...props} />;
}

function LocationTreePickerInner({
  tree,
  value,
  onChange,
  locale,
  showMap = true,
}: LocationTreePickerProps) {
  const t = useTranslations("location");
  const [mapOpen, setMapOpen] = useState(false);
  type AutoFillStatus =
    | "idle"
    | "loading"
    | "ok"
    | "partial"
    | "fail"
    | "denied"
    | "timeout"
    | "noGeolocation";
  const [autoFillStatus, setAutoFillStatus] = useState<AutoFillStatus>("idle");
  const geocodingLib = useMapsLibrary("geocoding");

  const region = useMemo(
    () => tree.find((n) => n.region.slug === value.regionSlug),
    [tree, value.regionSlug],
  );
  const governorate = useMemo(
    () => region?.governorates.find((g) => g.slug === value.governorateSlug),
    [region, value.governorateSlug],
  );
  const city = useMemo(
    () => governorate?.cities.find((c) => c.slug === value.citySlug),
    [governorate, value.citySlug],
  );

  function setField<K extends keyof LocationValue>(key: K, val: LocationValue[K]) {
    onChange({ ...value, [key]: val });
  }

  function onRegionChange(slug: string) {
    onChange({
      ...value,
      regionSlug: slug || null,
      governorateSlug: null,
      citySlug: null,
      districtName: "",
    });
  }
  function onGovernorateChange(slug: string) {
    onChange({
      ...value,
      governorateSlug: slug || null,
      citySlug: null,
      districtName: "",
    });
  }
  function onCityChange(slug: string) {
    onChange({
      ...value,
      citySlug: slug || null,
      districtName: "",
    });
  }

  async function reverseGeocode(lat: number, lng: number): Promise<ReverseGeocodeResult | null> {
    if (!geocodingLib) return null;
    try {
      const geocoder = new geocodingLib.Geocoder();
      const result = await geocoder.geocode({ location: { lat, lng } });
      if (!result.results || result.results.length === 0) return null;

      // Aggregate every component across returned results — more reliable than
      // picking just the first one.
      const collected: Record<string, string[]> = {};
      for (const r of result.results) {
        for (const comp of r.address_components ?? []) {
          for (const type of comp.types) {
            (collected[type] ??= []).push(comp.long_name);
          }
        }
      }

      // Pick first known of each.
      const adminArea1 = collected.administrative_area_level_1?.[0];
      const adminArea2 = collected.administrative_area_level_2?.[0];
      const locality = collected.locality?.[0] ?? collected.postal_town?.[0];
      const sublocality =
        collected.sublocality_level_1?.[0] ??
        collected.sublocality?.[0] ??
        collected.neighborhood?.[0] ??
        "";

      const regionSlug = matchSlug(
        tree.map((n) => n.region),
        adminArea1,
      );

      let governorateSlug: string | null = null;
      let citySlug: string | null = null;
      if (regionSlug) {
        const node = tree.find((n) => n.region.slug === regionSlug);
        if (node) {
          governorateSlug =
            matchSlug(node.governorates, adminArea2) ??
            matchSlug(node.governorates, locality);
          if (governorateSlug) {
            const gov = node.governorates.find((g) => g.slug === governorateSlug);
            if (gov) {
              citySlug =
                matchSlug(gov.cities, locality) ??
                matchSlug(gov.cities, adminArea2) ??
                (gov.cities[0]?.slug ?? null);
            }
          }
        }
      }

      return {
        regionSlug,
        governorateSlug,
        citySlug,
        district: sublocality,
      };
    } catch {
      return null;
    }
  }

  async function applyCoords(lat: number, lng: number) {
    // Always save the coordinates first — we want the pin on the map even if
    // geocoding fails or the maps library isn't ready yet.
    const next: LocationValue = { ...value, lat, lng };
    onChange(next);

    if (!geocodingLib) {
      // Maps library not ready yet — wait a moment and retry once.
      await new Promise((resolve) => setTimeout(resolve, 1500));
    }

    const geo = await reverseGeocode(lat, lng);
    if (geo) {
      const merged: LocationValue = { ...next };
      if (geo.regionSlug) merged.regionSlug = geo.regionSlug;
      if (geo.governorateSlug) merged.governorateSlug = geo.governorateSlug;
      if (geo.citySlug) merged.citySlug = geo.citySlug;
      if (geo.district && !merged.districtName) merged.districtName = geo.district;
      onChange(merged);
    }

    if (!geo || !geo.regionSlug) {
      setAutoFillStatus("partial");
    } else if (geo.governorateSlug && geo.citySlug) {
      setAutoFillStatus("ok");
    } else {
      setAutoFillStatus("partial");
    }
  }

  function useMyLocation() {
    // Open the map immediately so the user always sees a visible response.
    setMapOpen(true);
    setAutoFillStatus("loading");

    if (typeof navigator === "undefined" || !navigator.geolocation) {
      setAutoFillStatus("noGeolocation");
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (pos) => {
        void applyCoords(pos.coords.latitude, pos.coords.longitude);
      },
      (err) => {
        if (err.code === err.PERMISSION_DENIED) {
          setAutoFillStatus("denied");
        } else if (err.code === err.TIMEOUT) {
          setAutoFillStatus("timeout");
        } else {
          setAutoFillStatus("fail");
        }
      },
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 },
    );
  }

  // Reset auto-fill status when user edits dropdowns manually.
  useEffect(() => {
    if (autoFillStatus !== "idle" && autoFillStatus !== "loading") {
      const timer = setTimeout(() => setAutoFillStatus("idle"), 6000);
      return () => clearTimeout(timer);
    }
  }, [autoFillStatus]);

  const hasMapsKey = getGoogleMapsApiKey() !== null;

  return (
    <div className="space-y-4">
      {/* Prominent "use my location" CTA */}
      {showMap && (
        <div
          className="overflow-hidden rounded-lg border-2 border-primary bg-primary/5 p-4"
        >
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex items-start gap-3">
              <span className="grid h-11 w-11 flex-shrink-0 place-items-center rounded-md bg-primary text-primary-contrast shadow-sm">
                <Crosshair className="h-5 w-5" />
              </span>
              <div>
                <p className="text-base font-semibold text-text">{t("autoFillTitle")}</p>
                <p className="mt-0.5 text-xs leading-relaxed text-text-muted">
                  {t("autoFillBody")}
                </p>
              </div>
            </div>
            <button
              type="button"
              onClick={useMyLocation}
              disabled={autoFillStatus === "loading"}
              className="inline-flex h-11 flex-shrink-0 items-center justify-center gap-2 rounded-md bg-primary px-5 text-sm font-semibold text-primary-contrast shadow-sm hover:bg-primary-hover disabled:opacity-60"
            >
              <MapPin className="h-4 w-4" />
              <span>
                {autoFillStatus === "loading" ? t("locating") : t("useMyLocation")}
              </span>
            </button>
          </div>

          {autoFillStatus === "ok" && (
            <div className="mt-3 flex items-center gap-2 rounded-md bg-success/10 px-3 py-2 text-sm text-success">
              <CheckCircle2 className="h-4 w-4" />
              <span>{t("autoFillOk")}</span>
            </div>
          )}
          {autoFillStatus === "partial" && (
            <div className="mt-3 flex items-center gap-2 rounded-md bg-warning/10 px-3 py-2 text-sm text-warning">
              <AlertCircle className="h-4 w-4" />
              <span>{t("autoFillPartial")}</span>
            </div>
          )}
          {autoFillStatus === "denied" && (
            <div className="mt-3 flex items-center gap-2 rounded-md bg-danger/10 px-3 py-2 text-sm text-danger">
              <AlertCircle className="h-4 w-4" />
              <span>{t("autoFillDenied")}</span>
            </div>
          )}
          {autoFillStatus === "timeout" && (
            <div className="mt-3 flex items-center gap-2 rounded-md bg-warning/10 px-3 py-2 text-sm text-warning">
              <AlertCircle className="h-4 w-4" />
              <span>{t("autoFillTimeout")}</span>
            </div>
          )}
          {autoFillStatus === "noGeolocation" && (
            <div className="mt-3 flex items-center gap-2 rounded-md bg-warning/10 px-3 py-2 text-sm text-warning">
              <AlertCircle className="h-4 w-4" />
              <span>{t("autoFillNoGeolocation")}</span>
            </div>
          )}
          {autoFillStatus === "fail" && (
            <div className="mt-3 flex items-center gap-2 rounded-md bg-danger/10 px-3 py-2 text-sm text-danger">
              <AlertCircle className="h-4 w-4" />
              <span>{t("autoFillFail")}</span>
            </div>
          )}
          {!hasMapsKey && (
            <p className="mt-2 text-xs text-text-muted">{t("noMapsKey")}</p>
          )}
        </div>
      )}

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <div>
          <label className="mb-1.5 block text-sm font-medium text-text">{t("region")}</label>
          <select
            value={value.regionSlug ?? ""}
            onChange={(e) => onRegionChange(e.target.value)}
            className="h-11 w-full rounded-md border border-border bg-surface px-3 text-text outline-none focus:border-primary"
          >
            <option value="">{t("selectRegion")}</option>
            {tree.map((n) => (
              <option key={n.region.slug} value={n.region.slug}>
                {localized(n.region.name, locale)}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className="mb-1.5 block text-sm font-medium text-text">{t("governorate")}</label>
          <select
            value={value.governorateSlug ?? ""}
            onChange={(e) => onGovernorateChange(e.target.value)}
            disabled={!region}
            className="h-11 w-full rounded-md border border-border bg-surface px-3 text-text outline-none focus:border-primary disabled:opacity-50"
          >
            <option value="">{t("selectGovernorate")}</option>
            {region?.governorates.map((g) => (
              <option key={g.slug} value={g.slug}>
                {localized(g.name, locale)}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className="mb-1.5 block text-sm font-medium text-text">{t("city")}</label>
          <select
            value={value.citySlug ?? ""}
            onChange={(e) => onCityChange(e.target.value)}
            disabled={!governorate}
            className="h-11 w-full rounded-md border border-border bg-surface px-3 text-text outline-none focus:border-primary disabled:opacity-50"
          >
            <option value="">{t("selectCity")}</option>
            {governorate?.cities.map((c) => (
              <option key={c.slug} value={c.slug}>
                {localized(c.name, locale)}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        {city && city.districts.length > 0 ? (
          <div>
            <label className="mb-1.5 block text-sm font-medium text-text">
              {t("district")}
            </label>
            <select
              value={value.districtName}
              onChange={(e) => setField("districtName", e.target.value)}
              className="h-11 w-full rounded-md border border-border bg-surface px-3 text-text outline-none focus:border-primary"
            >
              <option value="">{t("selectDistrict")}</option>
              {city.districts.map((d) => {
                const label = d.name[locale] ?? d.name.ar ?? d.name.en ?? d.slug;
                return (
                  <option key={d.slug} value={label}>
                    {label}
                  </option>
                );
              })}
              <option value="__other__">{t("otherDistrict")}</option>
            </select>
          </div>
        ) : (
          <Input
            label={t("district")}
            placeholder={t("districtPlaceholder")}
            value={value.districtName}
            onChange={(e) => setField("districtName", e.target.value)}
          />
        )}
        <Input
          label={t("street")}
          placeholder={t("streetPlaceholder")}
          value={value.street}
          onChange={(e) => setField("street", e.target.value)}
        />
        <Input
          label={t("building")}
          placeholder={t("buildingPlaceholder")}
          value={value.building}
          onChange={(e) => setField("building", e.target.value)}
        />
      </div>

      {/* When user picked "Other" from the district dropdown, surface a free-text input */}
      {city && city.districts.length > 0 && value.districtName === "__other__" && (
        <Input
          label={t("districtOtherLabel")}
          placeholder={t("districtPlaceholder")}
          value=""
          onChange={(e) => setField("districtName", e.target.value)}
        />
      )}

      {showMap && (
        <div className="rounded-lg border border-border bg-surface-muted/40 p-4">
          <p className="mb-3 flex items-center gap-2 text-sm font-medium text-text">
            <MapPin className="h-4 w-4 text-primary" />
            <span>{t("mapTitle")}</span>
          </p>
          {mapOpen || value.lat != null ? (
            <LocationPicker
              height={280}
              defaultCenter={
                value.lat != null && value.lng != null
                  ? { lat: value.lat, lng: value.lng }
                  : undefined
              }
              onChange={(p) => void applyCoords(p.lat, p.lng)}
            />
          ) : (
            <button
              type="button"
              onClick={() => setMapOpen(true)}
              className="flex h-32 w-full items-center justify-center rounded-md border border-dashed border-border text-sm text-text-muted hover:bg-surface"
            >
              {t("openMap")}
            </button>
          )}
          {value.lat != null && value.lng != null && (
            <p className="mt-2 text-xs text-text-muted">
              {t("pinCoords")}: {value.lat.toFixed(4)}, {value.lng.toFixed(4)}
            </p>
          )}
        </div>
      )}
    </div>
  );
}
