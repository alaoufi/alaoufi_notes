import { describe, it, expect } from "vitest";
import { localized } from "@/lib/catalog/types";

describe("localized", () => {
  it("returns the requested locale when present", () => {
    expect(localized({ ar: "مرحبا", en: "Hello" }, "ar")).toBe("مرحبا");
    expect(localized({ ar: "مرحبا", en: "Hello" }, "en")).toBe("Hello");
  });

  it("falls back to ar then en when locale missing", () => {
    expect(localized({ ar: "مرحبا" }, "ur")).toBe("مرحبا");
    expect(localized({ en: "Hello" }, "hi")).toBe("Hello");
  });

  it("returns empty string for null/undefined", () => {
    expect(localized(null, "ar")).toBe("");
    expect(localized(undefined, "ar")).toBe("");
  });

  it("returns the first available value when neither ar nor en present", () => {
    expect(localized({ hi: "नमस्ते" }, "en")).toBe("नमस्ते");
  });
});
