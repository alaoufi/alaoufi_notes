"use client";

import { useState } from "react";
import { X, Image as ImageIcon } from "lucide-react";

export interface PortfolioItem {
  id: string;
  imageUrl: string;
  title?: string;
  description?: string;
}

interface Props {
  items: PortfolioItem[];
  emptyLabel: string;
}

/**
 * Portfolio gallery with a lightbox. Empty-state surfaces an icon so the
 * absence is obvious rather than just collapsing the section to 0 height.
 */
export function PortfolioGrid({ items, emptyLabel }: Props) {
  const [open, setOpen] = useState<PortfolioItem | null>(null);

  if (items.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center gap-2 rounded-lg border border-dashed border-border py-10 text-center text-sm text-text-muted">
        <ImageIcon className="h-8 w-8" />
        <p>{emptyLabel}</p>
      </div>
    );
  }

  return (
    <>
      <ul className="grid grid-cols-2 gap-2 sm:grid-cols-3 md:grid-cols-4">
        {items.map((it) => (
          <li key={it.id}>
            <button
              type="button"
              onClick={() => setOpen(it)}
              className="group relative block aspect-square w-full overflow-hidden rounded-md border border-border bg-surface-muted"
            >
              {/* eslint-disable-next-line @next/next/no-img-element -- portfolio images are external CDN, not local assets. */}
              <img
                src={it.imageUrl}
                alt={it.title ?? ""}
                loading="lazy"
                className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
              />
              {it.title && (
                <span className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/70 to-transparent px-2 py-1 text-[11px] font-medium text-white">
                  {it.title}
                </span>
              )}
            </button>
          </li>
        ))}
      </ul>

      {open && (
        <div
          role="dialog"
          aria-modal
          onClick={() => setOpen(null)}
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4"
        >
          <button
            type="button"
            onClick={() => setOpen(null)}
            className="absolute top-3 end-3 grid h-10 w-10 place-items-center rounded-pill bg-white/15 text-white hover:bg-white/25"
            aria-label="close"
          >
            <X className="h-5 w-5" />
          </button>
          <div
            onClick={(e) => e.stopPropagation()}
            className="max-h-[90vh] w-full max-w-3xl space-y-2"
          >
            {/* eslint-disable-next-line @next/next/no-img-element -- modal preview, no benefit from next/image. */}
            <img
              src={open.imageUrl}
              alt={open.title ?? ""}
              className="max-h-[80vh] w-full rounded-lg object-contain"
            />
            {(open.title || open.description) && (
              <div className="rounded-md bg-white/10 p-3 text-white">
                {open.title && <p className="text-sm font-semibold">{open.title}</p>}
                {open.description && (
                  <p className="mt-1 text-xs opacity-90">{open.description}</p>
                )}
              </div>
            )}
          </div>
        </div>
      )}
    </>
  );
}
