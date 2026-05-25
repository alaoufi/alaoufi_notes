// Verification provider interfaces. Concrete adapters (Taqnyat, Unifonic, Twilio, Nafath, ...)
// implement these. The auth flow code never imports a vendor directly.

export interface OtpSendParams {
  destination: string;     // E.164 phone or email
  code: string;            // already generated and ready to send
  locale: "ar" | "ur" | "en" | "hi" | "bn";
}

export interface OtpProvider {
  channel: "sms" | "whatsapp" | "email";
  send(params: OtpSendParams): Promise<{ messageId: string }>;
}

export interface NafathStartParams {
  nationalId: string;
  locale: "ar" | "en";
}

export interface NafathProvider {
  channel: "nafath";
  start(params: NafathStartParams): Promise<{ requestId: string; transactionId: string }>;
  verify(requestId: string): Promise<{ status: "pending" | "verified" | "rejected" }>;
}
