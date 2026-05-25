export interface LocationValue {
  regionSlug: string | null;
  governorateSlug: string | null;
  citySlug: string | null;
  districtName: string;
  street: string;
  building: string;
  lat: number | null;
  lng: number | null;
}

export interface LocationOption {
  slug: string;
  name: Record<string, string>;
}

export const emptyLocation: LocationValue = {
  regionSlug: null,
  governorateSlug: null,
  citySlug: null,
  districtName: "",
  street: "",
  building: "",
  lat: null,
  lng: null,
};
