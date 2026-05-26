import { describe, it, expect } from "vitest";
import { checkRateLimit } from "@/lib/security/rate-limit";
import { validateUpload } from "@/lib/security/upload-guard";

describe("rate-limit", () => {
  it("allows up to max requests then blocks", () => {
    const id = "test-user-1";
    for (let i = 0; i < 5; i++) {
      expect(checkRateLimit(id, { namespace: "t1", max: 5, windowMs: 60_000 }).ok).toBe(true);
    }
    expect(checkRateLimit(id, { namespace: "t1", max: 5, windowMs: 60_000 }).ok).toBe(false);
  });

  it("namespaces are independent", () => {
    const id = "test-user-2";
    for (let i = 0; i < 3; i++) {
      expect(checkRateLimit(id, { namespace: "ns-a", max: 3, windowMs: 60_000 }).ok).toBe(true);
    }
    expect(checkRateLimit(id, { namespace: "ns-a", max: 3, windowMs: 60_000 }).ok).toBe(false);
    // Same id, different namespace should still have full budget.
    expect(checkRateLimit(id, { namespace: "ns-b", max: 3, windowMs: 60_000 }).ok).toBe(true);
  });
});

describe("upload-guard", () => {
  it("accepts a 1MB jpeg", () => {
    expect(validateUpload({ size: 1_000_000, type: "image/jpeg", name: "photo.jpg" }).ok).toBe(true);
  });

  it("rejects a 20MB png as too large", () => {
    const r = validateUpload({ size: 20 * 1024 * 1024, type: "image/png", name: "huge.png" });
    expect(r.ok).toBe(false);
    expect(r.errorKey).toBe("tooLarge");
  });

  it("rejects executables even when mime claims pdf", () => {
    const r = validateUpload({ size: 1000, type: "application/pdf", name: "malware.exe" });
    expect(r.ok).toBe(false);
    expect(r.errorKey).toBe("suspicious");
  });

  it("rejects unknown mime types", () => {
    const r = validateUpload({ size: 1000, type: "application/x-msdownload" });
    expect(r.ok).toBe(false);
    expect(r.errorKey).toBe("wrongType");
  });

  it("accepts a webm voice note", () => {
    expect(validateUpload({ size: 100_000, type: "audio/webm" }).ok).toBe(true);
  });
});
