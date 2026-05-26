import { TrendingUp, Clock4, RefreshCcw, Trophy } from "lucide-react";

export interface ProviderStatsData {
  completionRate: number;     // 0..1, e.g. 0.97 → 97%
  responseTimeMin: number;    // average minutes to first response
  rebookRate: number;         // 0..1
  yearsActive: number;
}

interface Props {
  data: ProviderStatsData;
  labels: {
    completionRate: string;
    responseTime: string;
    rebookRate: string;
    yearsActive: string;
    responseUnit: string; // "min"
    yearsUnit: string;    // "years"
  };
}

export function ProviderStats({ data, labels }: Props) {
  const cards = [
    {
      icon: TrendingUp,
      label: labels.completionRate,
      value: `${Math.round(data.completionRate * 100)}%`,
      tone: "text-success",
    },
    {
      icon: Clock4,
      label: labels.responseTime,
      value: `${data.responseTimeMin} ${labels.responseUnit}`,
      tone: "text-info",
    },
    {
      icon: RefreshCcw,
      label: labels.rebookRate,
      value: `${Math.round(data.rebookRate * 100)}%`,
      tone: "text-accent",
    },
    {
      icon: Trophy,
      label: labels.yearsActive,
      value: `${data.yearsActive} ${labels.yearsUnit}`,
      tone: "text-warning",
    },
  ];

  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
      {cards.map((c) => (
        <div
          key={c.label}
          className="flex flex-col gap-1 rounded-lg border border-border bg-surface p-3"
        >
          <span className={`grid h-8 w-8 place-items-center rounded-md bg-surface-muted ${c.tone}`}>
            <c.icon className="h-4 w-4" />
          </span>
          <p className="text-base font-bold text-text">{c.value}</p>
          <p className="text-[11px] text-text-muted">{c.label}</p>
        </div>
      ))}
    </div>
  );
}
