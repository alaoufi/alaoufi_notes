export type MessageType = "text" | "image" | "file" | "voice" | "location" | "system";

export interface ChatMessage {
  id: string;
  type: MessageType;
  body?: string | null;
  senderId: string;
  senderName?: string;
  mediaUrl?: string | null;
  mediaMime?: string | null;
  mediaDurationMs?: number | null;
  latitude?: number | null;
  longitude?: number | null;
  createdAt: string;
  readBy?: string[];
}

export interface ChatParticipant {
  id: string;
  name: string;
  role: "requester" | "provider" | "system";
}
