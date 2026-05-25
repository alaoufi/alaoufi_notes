"use client";

import { useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { Input } from "@syanah/ui";
import { LocationPicker } from "@/components/map/location-picker";
import { localized } from "@/lib/catalog/types";
import type { Locale } from "@/i18n/locales";
import type { LocationValue } from "../types";
import { MapPin } from "lucide-react";

export interface TreeNode {
  region: { slug: string; name: Record<string, string> };
  governorates: Array<{
    slug: string;
    name: Record<string, string>;
    cities: Array<{ slug: string; name: Record<string, string> }>;
  }>;
}

export function LocationTreePicker({
  tree,
  value,
  onChange,
  locale,
  showMap = true,
}: {
  tree: TreeNode[];
  value: LocationValue;
  onChange: (next: LocationValue) => void;
  locale: Locale;
  showMap?: boolean;
}) {
  const t = useTranslations("location");
  const [mapOpen, setMapOpen] = useState(false);

  const region = useMemo(
    () => tree.find((n) => n.region.slug === value.regionSlug),
    [tree, value.regionSlug],
  );
  const governorate = useMemo(
    () => region?.governorates.find((g) => g.slug === value.governorateSlug),
    [region, value.governorateSlug],
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
    });
  }
  function onGovernorateChange(slug: string) {
    onChange({ ...value, governorateSlug: slug || null, citySlug: null });
  }
  function onCityChange(slug: string) {
    setField("citySlug", slug || null);
  }

  function useMyLocation() {
    if (typeof navigator === "undefined" || !navigator.geolocation) return;
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        onChange({
          ...value,
          lat: pos.coords.latitude,
          lng: pos.coords.longitude,
        });
        setMapOpen(true);
      },
      () => {
        setMapOpen(true);
      },
      { enableHighAccuracy: true, timeout: 6000 },
    );
  }

  return (
    <div className="space-y-4">
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
        <Input
          label={t("district")}
          placeholder={t("districtPlaceholder")}
          value={value.districtName}
          onChange={(e) => setField("districtName", e.target.value)}
        />
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

      {showMap && (
        <div className="rounded-lg border border-border bg-surface-muted/40 p-4">
          <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
            <div className="flex items-center gap-2 text-sm font-medium text-text">
              <MapPin className="h-4 w-4 text-primary" />
              <span>{t("mapTitle")}</span>
            </div>
            <button
              type="button"
              onClick={useMyLocation}
              className="inline-flex h-9 items-center gap-1 rounded-md bg-primary px-3 text-xs font-medium text-primary-contrast shadow-sm hover:bg-primary-hover"
            >
              <MapPin className="h-3.5 w-3.5" />
              {t("useMyLocation")}
            </button>
          </div>
          {mapOpen || value.lat != null ? (
            <LocationPicker
              height={280}
              defaultCenter={
                value.lat != null && value.lng != null
                  ? { lat: value.lat, lng: value.lng }
                  : undefined
              }
              onChange={(p) => onChange({ ...value, lat: p.lat, lng: p.lng })}
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
