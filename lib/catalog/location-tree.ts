import "server-only";
import { listActiveRegions, listGovernorates, listCities } from "./queries";
import type { Region, Governorate, City } from "./types";

export interface LocationTreeNode {
  region: Pick<Region, "slug" | "name">;
  governorates: Array<{
    slug: string;
    name: Record<string, string>;
    cities: Array<{ slug: string; name: Record<string, string> }>;
  }>;
}

/**
 * Build the full active geography tree (region → governorate → city) for
 * use in cascading pickers. Inactive nodes are pruned so customers only see
 * regions admins have opened up.
 */
export async function getActiveLocationTree(): Promise<LocationTreeNode[]> {
  const regions = await listActiveRegions();
  const allCities = await listCities();

  const tree: LocationTreeNode[] = [];

  for (const region of regions) {
    const govs = await listGovernorates(region.slug);
    const activeGovs = govs.filter((g) => g.is_active);

    const govNodes = activeGovs.map((g: Governorate) => {
      const cities = allCities
        .filter((c: City) => c.governorate_slug === g.slug || c.slug === g.slug)
        .map((c) => ({ slug: c.slug, name: c.name }));

      // If no cities are linked yet, expose the governorate itself as a city
      // option so the user can still pick a location while we're still seeding
      // sub-cities.
      const finalCities = cities.length > 0 ? cities : [{ slug: g.slug, name: g.name }];

      return { slug: g.slug, name: g.name, cities: finalCities };
    });

    tree.push({
      region: { slug: region.slug, name: region.name },
      governorates: govNodes,
    });
  }

  return tree;
}
