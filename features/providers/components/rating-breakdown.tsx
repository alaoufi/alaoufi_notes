import { Star, Clock, Wrench, MessageCircle } from "lucide-react";

export interface RatingBreakdownData {
  overall: number;        // 0..5
  count: number;
  punctuality: number;    // 0..5
  quality: number;        // 0..5
  communication: number;  // 0..5
  /** Distribution of star counts: index 0 = 1★, index 4 = 5★. */
  distribution?: [number, number, number, number, number];
}

interface Props {
  data: RatingBreakdownData;
  labels: {
    title: string;
    based: string; // "based on N reviews"
    overall: string;
    punctuality: string;
    quality: string;
    communication: string;
  };
}

function StarRow({ value }: { value: number }) {
  const full = Math.floor(value);
  const half = value - full >= 0.5;
  return (
    <div className="flex items-center gap-0.5">
      {Array.from({ length: 5 }).map((_, i) => {
        if (i < full) {
          return <Star key={i} className="h-3.5 w-3.5 fill-warning text-warning" />;
        }
        if (i === full && half) {
          return (
            <span key={i} className="relative inline-block h-3.5 w-3.5">
              <Star className="absolute inset-0 h-3.5 w-3.5 text-warning" />
              <Star
                className="absolute inset-0 h-3.5 w-3.5 fill-warning text-warning"
                style={{ clipPath: "inset(0 50% 0 0)" }}
              />
            </span>
          );
        }
        return <Star key={i} className="h-3.5 w-3.5 text-border" />;
      })}
    </div>
  );
}

function Criterion({
  icon: Icon,
  label,
  value,
}: {
  icon: typeof Star;
  label: string;
  value: number;
}) {
  return (
    <div className="flex items-center justify-between gap-3 py-2">
      <span className="inline-flex items-center gap-2 text-sm text-text">
        <Icon className="h-4 w-4 text-text-muted" />
        {label}
      </span>
      <div className="flex items-center gap-2">
        <span className="text-xs font-semibold tabular-nums text-text">{value.toFixed(1)}</span>
        <StarRow value={value} />
      </div>
    </div>
  );
}

export function RatingBreakdown({ data, labels }: Props) {
  const dist = data.distribution ?? [0, 0, 0, 0, 0];
  const total = dist.reduce((a, b) => a + b, 0) || 1;

  return (
    <div className="space-y-4">
      <div className="flex items-start gap-4">
        <div className="text-center">
          <p className="text-4xl font-bold leading-none text-text">
            {data.overall.toFixed(1)}
          </p>
          <div className="mt-1 flex justify-center">
            <StarRow value={data.overall} />
          </div>
          <p className="mt-1 text-xs text-text-muted">
            {labels.based.replace("{count}", String(data.count))}
          </p>
        </div>

        <ul className="flex-1 space-y-1">
          {([5, 4, 3, 2, 1] as const).map((s) => {
            const n = dist[s - 1] ?? 0;
            const pct = Math.round((n / total) * 100);
            return (
              <li key={s} className="flex items-center gap-2 text-[11px]">
                <span className="w-3 text-end text-text-muted">{s}</span>
                <Star className="h-3 w-3 fill-warning text-warning" />
                <span className="h-1.5 flex-1 overflow-hidden rounded-pill bg-surface-muted">
                  <span
                    className="block h-full rounded-pill bg-warning"
                    style={{ width: `${pct}%` }}
                  />
                </span>
                <span className="w-8 text-text-muted">{pct}%</span>
              </li>
            );
          })}
        </ul>
      </div>

      <div className="border-t border-border pt-2">
        <Criterion icon={Clock}          label={labels.punctuality}   value={data.punctuality} />
        <Criterion icon={Wrench}         label={labels.quality}       value={data.quality} />
        <Criterion icon={MessageCircle}  label={labels.communication} value={data.communication} />
      </div>
    </div>
  );
}
