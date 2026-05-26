/**
 * Lightweight SVG charts — no extra deps. recharts would add ~200KB to the
 * client bundle for what we render here, so we hand-roll a sparkline area
 * and a bar chart. They scale to container width and degrade gracefully
 * when the dataset is empty.
 */

interface LineChartProps {
  data: { label: string; value: number }[];
  height?: number;
  ariaLabel?: string;
}

export function MiniAreaChart({ data, height = 120, ariaLabel }: LineChartProps) {
  if (data.length === 0) {
    return (
      <div className="grid h-[120px] place-items-center rounded-md border border-dashed border-border text-xs text-text-muted">
        لا توجد بيانات بعد
      </div>
    );
  }
  const W = 600;
  const H = height;
  const pad = 8;
  const max = Math.max(...data.map((d) => d.value), 1);
  const step = (W - pad * 2) / Math.max(data.length - 1, 1);

  const points = data.map((d, i) => ({
    x: pad + i * step,
    y: pad + (H - pad * 2) * (1 - d.value / max),
  }));

  const linePath = points
    .map((p, i) => `${i === 0 ? "M" : "L"} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`)
    .join(" ");
  const areaPath =
    linePath +
    ` L ${points[points.length - 1]!.x.toFixed(1)} ${H - pad} L ${points[0]!.x.toFixed(1)} ${H - pad} Z`;

  return (
    <svg
      viewBox={`0 0 ${W} ${H}`}
      role="img"
      aria-label={ariaLabel}
      preserveAspectRatio="none"
      className="block h-[120px] w-full"
    >
      <defs>
        <linearGradient id="areaGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="currentColor" stopOpacity="0.25" />
          <stop offset="100%" stopColor="currentColor" stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={areaPath} fill="url(#areaGrad)" className="text-primary" />
      <path d={linePath} fill="none" stroke="currentColor" strokeWidth={2} className="text-primary" />
      {points.map((p, i) => (
        <circle key={i} cx={p.x} cy={p.y} r={2.5} className="fill-primary" />
      ))}
    </svg>
  );
}

interface BarChartProps {
  data: { label: string; value: number }[];
  height?: number;
  ariaLabel?: string;
}

export function MiniBarChart({ data, height = 140, ariaLabel }: BarChartProps) {
  if (data.length === 0) {
    return (
      <div className="grid h-[140px] place-items-center rounded-md border border-dashed border-border text-xs text-text-muted">
        لا توجد بيانات بعد
      </div>
    );
  }
  const W = 600;
  const H = height;
  const pad = 24;
  const max = Math.max(...data.map((d) => d.value), 1);
  const innerW = W - pad * 2;
  const innerH = H - pad * 2;
  const slot = innerW / data.length;
  const barW = Math.min(slot * 0.6, 40);

  return (
    <svg
      viewBox={`0 0 ${W} ${H}`}
      role="img"
      aria-label={ariaLabel}
      preserveAspectRatio="none"
      className="block h-[140px] w-full"
    >
      {data.map((d, i) => {
        const x = pad + i * slot + (slot - barW) / 2;
        const h = (d.value / max) * innerH;
        const y = pad + (innerH - h);
        return (
          <g key={i}>
            <rect
              x={x}
              y={y}
              width={barW}
              height={h}
              rx={3}
              className="fill-primary/80"
            />
            <text
              x={x + barW / 2}
              y={pad + innerH + 14}
              textAnchor="middle"
              className="fill-current text-[10px]"
              style={{ fill: "currentColor" }}
            >
              {d.label}
            </text>
          </g>
        );
      })}
    </svg>
  );
}
