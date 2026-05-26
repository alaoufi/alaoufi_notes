import { Check, Clock, Truck, Wrench, Flag, X, AlertTriangle } from "lucide-react";
import type { OrderStatus } from "../types";

type StepKey = "pending" | "accepted" | "en_route" | "in_progress" | "completed";

interface Step {
  key: StepKey;
  icon: typeof Clock;
  labelKey: string;
}

const STEPS: Step[] = [
  { key: "pending",     icon: Clock,  labelKey: "timeline.pending"     },
  { key: "accepted",    icon: Check,  labelKey: "timeline.accepted"    },
  { key: "en_route",    icon: Truck,  labelKey: "timeline.enRoute"     },
  { key: "in_progress", icon: Wrench, labelKey: "timeline.inProgress"  },
  { key: "completed",   icon: Flag,   labelKey: "timeline.completed"   },
];

// Mapping of the live status onto the timeline position: every step at or
// before the current one is "done", current is "current", later steps are "pending".
function progressIndex(status: OrderStatus): number {
  switch (status) {
    case "draft":
    case "pending":     return 0;
    case "accepted":    return 1;
    case "en_route":    return 2;
    case "in_progress": return 3;
    case "completed":   return 4;
    default:            return -1; // cancelled / rejected / disputed handled separately
  }
}

export interface TimelineEvent {
  key: StepKey | OrderStatus;
  at: string;
  note?: string;
}

interface Props {
  status: OrderStatus;
  events?: TimelineEvent[];
  labels: {
    pending: string;
    accepted: string;
    enRoute: string;
    inProgress: string;
    completed: string;
    cancelled: string;
    rejected: string;
    disputed: string;
  };
}

export function OrderTimeline({ status, events = [], labels }: Props) {
  // Terminal sad states get their own rail to avoid pretending steps were reached.
  if (status === "cancelled" || status === "rejected") {
    return (
      <div className="flex items-center gap-3 rounded-md border border-danger/30 bg-danger/5 p-3 text-sm text-danger">
        <X className="h-5 w-5 shrink-0" />
        <span>{status === "cancelled" ? labels.cancelled : labels.rejected}</span>
      </div>
    );
  }
  if (status === "disputed") {
    return (
      <div className="flex items-center gap-3 rounded-md border border-warning/30 bg-warning/5 p-3 text-sm text-warning">
        <AlertTriangle className="h-5 w-5 shrink-0" />
        <span>{labels.disputed}</span>
      </div>
    );
  }

  const idx = progressIndex(status);
  const eventByKey = new Map<string, TimelineEvent>();
  for (const e of events) eventByKey.set(String(e.key), e);

  return (
    <ol className="relative space-y-4">
      {STEPS.map((step, i) => {
        const state: "done" | "current" | "pending" =
          i < idx ? "done" : i === idx ? "current" : "pending";
        const Icon = step.icon;
        const ev = eventByKey.get(step.key);
        const label =
          step.key === "pending"     ? labels.pending     :
          step.key === "accepted"    ? labels.accepted    :
          step.key === "en_route"    ? labels.enRoute     :
          step.key === "in_progress" ? labels.inProgress  :
          /* completed */              labels.completed;
        return (
          <li key={step.key} className="flex gap-3">
            <div className="flex flex-col items-center">
              <span
                className={`grid h-9 w-9 place-items-center rounded-pill border-2 transition-colors ${
                  state === "done"
                    ? "border-success bg-success text-white"
                    : state === "current"
                      ? "border-primary bg-primary text-primary-contrast animate-pulse"
                      : "border-border bg-surface text-text-muted"
                }`}
              >
                <Icon className="h-4 w-4" />
              </span>
              {i < STEPS.length - 1 && (
                <span
                  className={`mt-1 w-0.5 flex-1 ${
                    state === "done" ? "bg-success" : "bg-border"
                  }`}
                  style={{ minHeight: 24 }}
                />
              )}
            </div>
            <div className="flex-1 pb-4">
              <p
                className={`text-sm font-medium ${
                  state === "pending" ? "text-text-muted" : "text-text"
                }`}
              >
                {label}
              </p>
              {ev?.at && (
                <p className="text-xs text-text-muted">
                  {new Date(ev.at).toLocaleString(undefined, {
                    hour: "2-digit",
                    minute: "2-digit",
                    day: "numeric",
                    month: "short",
                  })}
                </p>
              )}
              {ev?.note && <p className="mt-1 text-xs text-text-muted">{ev.note}</p>}
            </div>
          </li>
        );
      })}
    </ol>
  );
}
