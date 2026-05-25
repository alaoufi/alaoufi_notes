import { Badge } from "@syanah/ui";
import { useTranslations } from "next-intl";
import type { OrderStatus } from "../types";

const toneMap: Record<OrderStatus, "neutral" | "primary" | "success" | "warning" | "danger" | "info"> = {
  draft: "neutral",
  pending: "warning",
  accepted: "info",
  rejected: "danger",
  en_route: "info",
  in_progress: "primary",
  completed: "success",
  cancelled: "neutral",
  disputed: "danger",
};

export function OrderStatusBadge({ status }: { status: OrderStatus }) {
  const t = useTranslations("orders.status");
  return <Badge tone={toneMap[status]}>{t(status)}</Badge>;
}
