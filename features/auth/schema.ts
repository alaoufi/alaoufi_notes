import { z } from "zod";

export const signUpSchema = z.object({
  fullName: z.string().min(2, "auth.errors.fullNameTooShort").max(120),
  email: z.string().email("auth.errors.emailInvalid"),
  phone: z
    .string()
    .regex(/^\+?[1-9]\d{7,14}$/, "auth.errors.phoneInvalid")
    .transform((v) => (v.startsWith("+") ? v : `+${v}`)),
  password: z
    .string()
    .min(8, "auth.errors.passwordTooShort")
    .regex(/[A-Z]/, "auth.errors.passwordWeak")
    .regex(/[a-z]/, "auth.errors.passwordWeak")
    .regex(/[0-9]/, "auth.errors.passwordWeak"),
  role: z.enum(["requester", "provider"]),
  locale: z.enum(["ar", "ur", "en", "hi", "bn"]).default("ar"),
});

export type SignUpInput = z.infer<typeof signUpSchema>;

export const signInSchema = z.object({
  email: z.string().email("auth.errors.emailInvalid"),
  password: z.string().min(1, "auth.errors.passwordRequired"),
});

export type SignInInput = z.infer<typeof signInSchema>;
