import { Check, CheckCheck, Clock, AlertCircle } from "lucide-react";
import type { MessageStatus } from "../types";

/**
 * WhatsApp-style delivery state:
 *   sending   → ⏱ (clock)
 *   sent      → ✓ (single gray)
 *   delivered → ✓✓ (double gray)
 *   read      → ✓✓ (double blue)
 *   failed    → ⓘ (red)
 */
export function ReadReceipt({ status }: { status?: MessageStatus }) {
  if (!status) return null;
  if (status === "sending") {
    return <Clock className="h-3 w-3 opacity-70" aria-label="sending" />;
  }
  if (status === "sent") {
    return <Check className="h-3.5 w-3.5 opacity-70" aria-label="sent" />;
  }
  if (status === "delivered") {
    return <CheckCheck className="h-3.5 w-3.5 opacity-70" aria-label="delivered" />;
  }
  if (status === "read") {
    return (
      <CheckCheck className="h-3.5 w-3.5 text-[#34b7f1]" aria-label="read" />
    );
  }
  if (status === "failed") {
    return <AlertCircle className="h-3.5 w-3.5 text-danger" aria-label="failed" />;
  }
  return null;
}
