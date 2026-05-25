import { describe, it, expect } from "vitest";
import { getDirection, locales, defaultLocale, localeNames } from "@/i18n/locales";

describe("locales", () => {
  it("ar is default", () => {
    expect(defaultLocale).toBe("ar");
  });

  it("exports all 5 locales", () => {
    expect(locales).toHaveLength(5);
    expect(locales).toContain("ar");
    expect(locales).toContain("ur");
    expect(locales).toContain("en");
    expect(locales).toContain("hi");
    expect(locales).toContain("bn");
  });

  it("has a display name for every locale", () => {
    for (const loc of locales) {
      expect(localeNames[loc]).toBeTruthy();
    }
  });

  it("returns rtl only for ar and ur", () => {
    expect(getDirection("ar")).toBe("rtl");
    expect(getDirection("ur")).toBe("rtl");
    expect(getDirection("en")).toBe("ltr");
    expect(getDirection("hi")).toBe("ltr");
    expect(getDirection("bn")).toBe("ltr");
  });
});
