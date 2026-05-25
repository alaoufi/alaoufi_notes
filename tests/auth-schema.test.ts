import { describe, it, expect } from "vitest";
import { signUpSchema, signInSchema } from "@/features/auth/schema";

describe("signUpSchema", () => {
  it("accepts a valid signup payload", () => {
    const result = signUpSchema.safeParse({
      fullName: "Ahmed",
      email: "ahmed@example.com",
      phone: "+966500000000",
      password: "Aa1bbbbb",
      role: "requester",
      locale: "ar",
    });
    expect(result.success).toBe(true);
  });

  it("rejects short passwords", () => {
    const result = signUpSchema.safeParse({
      fullName: "Ahmed",
      email: "ahmed@example.com",
      phone: "+966500000000",
      password: "Aa1",
      role: "requester",
    });
    expect(result.success).toBe(false);
  });

  it("rejects weak password without digit", () => {
    const result = signUpSchema.safeParse({
      fullName: "Ahmed",
      email: "ahmed@example.com",
      phone: "+966500000000",
      password: "Abcdefgh",
      role: "requester",
    });
    expect(result.success).toBe(false);
  });

  it("rejects invalid phone", () => {
    const result = signUpSchema.safeParse({
      fullName: "Ahmed",
      email: "ahmed@example.com",
      phone: "not-a-phone",
      password: "Aa1bbbbb",
      role: "requester",
    });
    expect(result.success).toBe(false);
  });

  it("accepts phone without leading + and normalizes it", () => {
    const result = signUpSchema.safeParse({
      fullName: "Ahmed",
      email: "ahmed@example.com",
      phone: "966500000000",
      password: "Aa1bbbbb",
      role: "requester",
    });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.phone).toBe("+966500000000");
    }
  });
});

describe("signInSchema", () => {
  it("requires email and password", () => {
    expect(signInSchema.safeParse({ email: "bad" }).success).toBe(false);
    expect(signInSchema.safeParse({ email: "a@b.com", password: "x" }).success).toBe(true);
  });
});
