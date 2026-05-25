import { describe, it, expect } from "vitest";
import {
  signUpSchema,
  signInSchema,
  detectHandleKind,
} from "@/features/auth/schema";

const baseLocation = {
  regionSlug: "riyadh",
  governorateSlug: "riyadh",
  citySlug: "riyadh",
};

const basePayload = {
  fullName: "Ahmed",
  email: "ahmed@example.com",
  phone: "+966500000000",
  password: "Aa1bbbbb",
  roles: ["requester" as const],
  activeRole: "requester" as const,
  locale: "ar" as const,
  ...baseLocation,
};

describe("signUpSchema", () => {
  it("accepts a valid signup payload", () => {
    const result = signUpSchema.safeParse(basePayload);
    expect(result.success).toBe(true);
  });

  it("accepts when email is omitted (email is optional)", () => {
    const result = signUpSchema.safeParse({ ...basePayload, email: "" });
    expect(result.success).toBe(true);
  });

  it("accepts a valid optional username", () => {
    const result = signUpSchema.safeParse({ ...basePayload, username: "ahmed_m" });
    expect(result.success).toBe(true);
  });

  it("rejects an invalid username", () => {
    const result = signUpSchema.safeParse({ ...basePayload, username: "Ahmed!" });
    expect(result.success).toBe(false);
  });

  it("accepts dual roles + activeRole that matches", () => {
    const result = signUpSchema.safeParse({
      ...basePayload,
      roles: ["requester", "provider"],
      activeRole: "provider",
    });
    expect(result.success).toBe(true);
  });

  it("rejects empty roles array", () => {
    const result = signUpSchema.safeParse({ ...basePayload, roles: [] });
    expect(result.success).toBe(false);
  });

  it("rejects short passwords", () => {
    const result = signUpSchema.safeParse({ ...basePayload, password: "Aa1" });
    expect(result.success).toBe(false);
  });

  it("rejects weak password without digit", () => {
    const result = signUpSchema.safeParse({ ...basePayload, password: "Abcdefgh" });
    expect(result.success).toBe(false);
  });

  it("rejects invalid phone", () => {
    const result = signUpSchema.safeParse({ ...basePayload, phone: "not-a-phone" });
    expect(result.success).toBe(false);
  });

  it("rejects missing region", () => {
    const result = signUpSchema.safeParse({ ...basePayload, regionSlug: "" });
    expect(result.success).toBe(false);
  });

  it("normalises phone without +", () => {
    const result = signUpSchema.safeParse({ ...basePayload, phone: "966500000000" });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.phone).toBe("+966500000000");
    }
  });
});

describe("signInSchema", () => {
  it("requires handle and password", () => {
    expect(signInSchema.safeParse({ handle: "", password: "x" }).success).toBe(false);
    expect(signInSchema.safeParse({ handle: "ahmed", password: "" }).success).toBe(false);
    expect(signInSchema.safeParse({ handle: "ahmed", password: "x" }).success).toBe(true);
  });
});

describe("detectHandleKind", () => {
  it("detects emails", () => {
    expect(detectHandleKind("a@b.com")).toBe("email");
  });
  it("detects phones", () => {
    expect(detectHandleKind("+966500000000")).toBe("phone");
    expect(detectHandleKind("0500000000")).toBe("phone");
  });
  it("treats anything else as username", () => {
    expect(detectHandleKind("ahmed_m")).toBe("username");
  });
});
