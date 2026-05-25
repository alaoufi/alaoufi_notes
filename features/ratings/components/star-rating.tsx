"use client";

import { useState } from "react";
import { Star } from "lucide-react";
import { cn } from "@syanah/ui";

export function StarRating({
  value,
  onChange,
  size = 28,
  readonly = false,
}: {
  value: number;
  onChange?: (v: number) => void;
  size?: number;
  readonly?: boolean;
}) {
  const [hover, setHover] = useState<number | null>(null);
  const display = hover ?? value;

  return (
    <div className="flex items-center gap-1" role="radiogroup" aria-label="rating">
      {[1, 2, 3, 4, 5].map((n) => {
        const active = n <= display;
        return (
          <button
            key={n}
            type="button"
            disabled={readonly}
            onMouseEnter={() => !readonly && setHover(n)}
            onMouseLeave={() => !readonly && setHover(null)}
            onClick={() => !readonly && onChange?.(n)}
            aria-checked={n === value}
            role="radio"
            className={cn(
              "transition-transform",
              !readonly && "hover:scale-110 focus:outline-none",
              readonly && "cursor-default",
            )}
          >
            <Star
              width={size}
              height={size}
              className={active ? "fill-warning text-warning" : "text-border"}
            />
          </button>
        );
      })}
    </div>
  );
}
