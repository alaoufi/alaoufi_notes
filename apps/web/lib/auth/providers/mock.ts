import type { NafathProvider, OtpProvider } from "./types";

// Mock providers used in `local` and `preview` environments. They never call out to a
// real vendor. Production must wire concrete adapters in lib/auth/providers/index.ts.

export const mockSmsProvider: OtpProvider = {
  channel: "sms",
  async send({ destination, code }) {
    // eslint-disable-next-line no-console
    console.log(`[mock sms] would send code ${code} to ${destination}`);
    return { messageId: `mock-sms-${Date.now()}` };
  },
};

export const mockWhatsappProvider: OtpProvider = {
  channel: "whatsapp",
  async send({ destination, code }) {
    // eslint-disable-next-line no-console
    console.log(`[mock whatsapp] would send code ${code} to ${destination}`);
    return { messageId: `mock-wa-${Date.now()}` };
  },
};

export const mockEmailProvider: OtpProvider = {
  channel: "email",
  async send({ destination, code }) {
    // eslint-disable-next-line no-console
    console.log(`[mock email] would send code ${code} to ${destination}`);
    return { messageId: `mock-email-${Date.now()}` };
  },
};

export const mockNafathProvider: NafathProvider = {
  channel: "nafath",
  async start({ nationalId }) {
    // eslint-disable-next-line no-console
    console.log(`[mock nafath] would start tx for ${nationalId}`);
    return { requestId: `mock-req-${Date.now()}`, transactionId: "12" };
  },
  async verify() {
    return { status: "verified" };
  },
};
