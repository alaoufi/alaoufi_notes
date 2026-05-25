// Minimal hand-written types for now. Will be replaced by:
//   pnpm dlx supabase gen types typescript --project-id <id> > apps/web/lib/supabase/types.ts
// once the Supabase project is provisioned.

export type Role = "super_admin" | "section_admin" | "provider" | "requester";
export type VerificationMethod = "nafath" | "sms" | "whatsapp" | "email";
export type VerificationStatus = "pending" | "verified" | "expired" | "failed";

export interface Profile {
  user_id: string;
  full_name: string | null;
  phone_e164: string | null;
  email_normalized: string | null;
  preferred_locale: "ar" | "ur" | "en" | "hi" | "bn";
  preferred_theme: "navy" | "stc" | "fuchsia";
  avatar_path: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface UserRole {
  user_id: string;
  role: Role;
  granted_by: string | null;
  granted_at: string;
}

export interface Database {
  public: {
    Tables: {
      profiles: { Row: Profile; Insert: Partial<Profile> & { user_id: string }; Update: Partial<Profile> };
      user_roles: { Row: UserRole; Insert: UserRole; Update: Partial<UserRole> };
    };
  };
}
