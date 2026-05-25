import { z } from "zod";

export const usernameRegex = /^[a-z0-9_]{3,30}$/;
export const phoneRegex = /^\+?[1-9]\d{7,14}$/;

export const signUpSchema = z.object({
  fullName: z.string().min(2, "auth.errors.fullNameTooShort").max(120),
  username: z
    .string()
    .trim()
    .toLowerCase()
    .regex(usernameRegex, "auth.errors.usernameInvalid")
    .optional()
    .or(z.literal("")),
  email: z
    .string()
    .email("auth.errors.emailInvalid")
    .optional()
    .or(z.literal("")),
  phone: z
    .string()
    .regex(phoneRegex, "auth.errors.phoneInvalid")
    .transform((v) => (v.startsWith("+") ? v : `+${v}`)),
  password: z
    .string()
    .min(8, "auth.errors.passwordTooShort")
    .regex(/[A-Z]/, "auth.errors.passwordWeak")
    .regex(/[a-z]/, "auth.errors.passwordWeak")
    .regex(/[0-9]/, "auth.errors.passwordWeak"),
  roles: z
    .array(z.enum(["requester", "provider"]))
    .min(1, "auth.errors.roleRequired"),
  activeRole: z.enum(["requester", "provider"]),
  locale: z.enum(["ar", "ur", "en", "hi", "bn"]).default("ar"),

  // Address — at least region + governorate + city are required.
  regionSlug: z.string().min(1, "auth.errors.regionRequired"),
  governorateSlug: z.string().min(1, "auth.errors.governorateRequired"),
  citySlug: z.string().min(1, "auth.errors.cityRequired"),
  districtName: z.string().max(120).optional().default(""),
  street: z.string().max(200).optional().default(""),
  building: z.string().max(60).optional().default(""),
  lat: z.number().nullable().optional(),
  lng: z.number().nullable().optional(),
});

export type SignUpInput = z.infer<typeof signUpSchema>;

/**
 * Sign-in accepts ONE handle (username, phone, or email) plus a password.
 * The server action resolves the handle to the underlying auth identifier.
 */
export const signInSchema = z.object({
  handle: z.string().trim().min(1, "auth.errors.handleRequired"),
  password: z.string().min(1, "auth.errors.passwordRequired"),
});

export type SignInInput = z.infer<typeof signInSchema>;

export function detectHandleKind(handle: string): "email" | "phone" | "username" {
  const trimmed = handle.trim();
  if (trimmed.includes("@")) return "email";
  if (phoneRegex.test(trimmed) || /^[+0-9]/.test(trimmed)) return "phone";
  return "username";
}
