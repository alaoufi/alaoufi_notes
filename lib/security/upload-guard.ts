/**
 * Upload validation shared between client (composer) and server (action).
 *
 * The client-side check is UX (fail fast, no upload); the server-side check
 * is the actual security gate because the client can be bypassed. Both share
 * this module so the rules stay in lockstep.
 */

export const MAX_UPLOAD_BYTES = 15 * 1024 * 1024; // 15 MB

export const ALLOWED_IMAGE_MIME = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
  "image/heic",
  "image/heif",
] as const;

export const ALLOWED_DOC_MIME = [
  "application/pdf",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "text/plain",
] as const;

export const ALLOWED_AUDIO_MIME = [
  "audio/webm",
  "audio/ogg",
  "audio/mpeg",
  "audio/mp4",
  "audio/aac",
] as const;

const ALL_ALLOWED = new Set<string>([
  ...ALLOWED_IMAGE_MIME,
  ...ALLOWED_DOC_MIME,
  ...ALLOWED_AUDIO_MIME,
]);

// Reject anything resembling an executable or script even if the mime says
// something benign — the magic-bytes check at upload time is the real gate,
// but pattern-matching the name catches the lazy attempt.
const SUSPICIOUS_EXT = /\.(?:exe|bat|cmd|sh|js|jar|com|scr|msi|vbs|ps1|html?)$/i;

export interface UploadCheckResult {
  ok: boolean;
  errorKey?: "tooLarge" | "wrongType" | "suspicious";
}

interface UploadCandidate {
  size: number;
  type: string;
  name?: string;
}

export function validateUpload(file: UploadCandidate): UploadCheckResult {
  if (file.size > MAX_UPLOAD_BYTES) return { ok: false, errorKey: "tooLarge" };
  if (file.name && SUSPICIOUS_EXT.test(file.name)) {
    return { ok: false, errorKey: "suspicious" };
  }
  if (!ALL_ALLOWED.has(file.type)) {
    return { ok: false, errorKey: "wrongType" };
  }
  return { ok: true };
}
