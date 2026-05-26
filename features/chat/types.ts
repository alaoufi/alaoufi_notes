export type MessageType = "text" | "image" | "file" | "voice" | "location" | "system";

/**
 * Delivery state shown as gray/blue check marks (WhatsApp convention):
 *   - sending   → clock icon
 *   - sent      → single gray check
 *   - delivered → double gray check
 *   - read      → double blue check
 */
export type MessageStatus = "sending" | "sent" | "delivered" | "read" | "failed";

export interface ChatMessage {
  id: string;
  type: MessageType;
  body?: string | null;
  senderId: string;
  senderName?: string;
  mediaUrl?: string | null;
  mediaMime?: string | null;
  mediaName?: string | null;
  mediaSize?: number | null;
  mediaDurationMs?: number | null;
  latitude?: number | null;
  longitude?: number | null;
  createdAt: string;
  readBy?: string[];
  status?: MessageStatus;
}

export interface ChatParticipant {
  id: string;
  name: string;
  role: "requester" | "provider" | "system";
}
