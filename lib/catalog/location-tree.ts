import "server-only";
import {
  listActiveRegions,
  listGovernorates,
  listCities,
  listDistricts,
} from "./queries";
import type { Region, Governorate, City, District } from "./types";

export interface LocationTreeCity {
  slug: string;
  name: Record<string, string>;
  districts: Array<{
    slug: string;
    name: Record<string, string>;
    lat: number | null;
    lng: number | null;
  }>;
}

export interface LocationTreeNode {
  region: Pick<Region, "slug" | "name">;
  governorates: Array<{
    slug: string;
    name: Record<string, string>;
    cities: LocationTreeCity[];
  }>;
}

/**
 * Build the full active geography tree (region → governorate → city →
 * district) for cascading pickers. Inactive nodes are pruned so customers
 * only see locations admins have opened up.
 *
 * Each city carries its own districts array so the picker can present a
 * 4th dropdown when districts exist, or fall back to a free-text district
 * input when they don't.
 */
export async function getActiveLocationTree(): Promise<LocationTreeNode[]> {
  const regions = await listActiveRegions();
  const allCities = await listCities();

  const tree: LocationTreeNode[] = [];

  for (const region of regions) {
    const govs = await listGovernorates(region.slug);
    const activeGovs = govs.filter((g) => g.is_active);

    const govNodes = await Promise.all(
      activeGovs.map(async (g: Governorate) => {
        let cities = allCities
          .filter((c: City) => c.governorate_slug === g.slug || c.slug === g.slug)
          .map<LocationTreeCity>((c) => ({
            slug: c.slug,
            name: c.name,
            districts: [],
          }));

        // If no real cities are linked, surface the governorate itself as a
        // selectable "city" so the cascade is never empty.
        if (cities.length === 0) {
          cities = [{ slug: g.slug, name: g.name, districts: [] }];
        }

        // Attach districts per city in parallel.
        await Promise.all(
          cities.map(async (city) => {
            const districts = await listDistricts(city.slug);
            city.districts = districts.map((d: District) => ({
              slug: d.slug,
              name: d.name,
              lat: d.lat ?? null,
              lng: d.lng ?? null,
            }));
          }),
        );

        return { slug: g.slug, name: g.name, cities };
      }),
    );

    tree.push({
      region: { slug: region.slug, name: region.name },
      governorates: govNodes,
    });
  }

  return tree;
}
