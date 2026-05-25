export type AuthErrorCode =
  | "INVALID_INPUT"
  | "USER_EXISTS"
  | "INVALID_CREDENTIALS"
  | "OTP_EXPIRED"
  | "OTP_INVALID"
  | "OTP_TOO_MANY"
  | "PROVIDER_DOWN"
  | "RATE_LIMITED"
  | "UNKNOWN";

export class AuthError extends Error {
  code: AuthErrorCode;
  messageKey: string;

  constructor(code: AuthErrorCode, messageKey: string, cause?: unknown) {
    super(messageKey);
    this.code = code;
    this.messageKey = messageKey;
    if (cause) this.cause = cause;
  }
}
