import {
  mockEmailProvider,
  mockNafathProvider,
  mockSmsProvider,
  mockWhatsappProvider,
} from "./mock";
import type { NafathProvider, OtpProvider } from "./types";

// Provider selection. Until real adapters are added (Phase 3 integration), we use mocks.
// To switch a channel to a real provider:
//   1. Implement `lib/auth/providers/<vendor>.ts` exporting an OtpProvider/NafathProvider.
//   2. Replace the export here.
//   3. Add the vendor credentials to .env.example and Vercel/Supabase env.

export const smsProvider: OtpProvider = mockSmsProvider;
export const whatsappProvider: OtpProvider = mockWhatsappProvider;
export const emailProvider: OtpProvider = mockEmailProvider;
export const nafathProvider: NafathProvider = mockNafathProvider;
