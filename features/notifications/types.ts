export type NotificationKind =
  | "order_update"
  | "chat_message"
  | "payment"
  | "rating"
  | "system";

export interface AppNotification {
  id: string;
  kind: NotificationKind;
  titleKey?: string;
  /** Pre-translated title — used when key isn't enough (e.g., contains a name). */
  title?: string;
  body?: string;
  /** Deep-link target (e.g., `/orders/abc`). */
  href?: string;
  createdAt: string;
  readAt?: string | null;
}
