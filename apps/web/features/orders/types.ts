export type OrderStatus =
  | "draft"
  | "pending"
  | "accepted"
  | "rejected"
  | "en_route"
  | "in_progress"
  | "completed"
  | "cancelled"
  | "disputed";

export interface OrderSummary {
  id: string;
  code: string;
  status: OrderStatus;
  categorySlug: string;
  categoryName: Record<string, string>;
  scheduledAt?: string | null;
  createdAt: string;
  addressLabel: string;
  total?: number | null;
}
