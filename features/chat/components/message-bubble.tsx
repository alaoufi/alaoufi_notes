import { cn } from "@syanah/ui";
import { MapPin, Mic, Paperclip, FileText, Play } from "lucide-react";
import type { ChatMessage } from "../types";
import { ReadReceipt } from "./read-receipt";

function formatSize(bytes?: number | null): string {
  if (!bytes || bytes <= 0) return "";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

function formatDuration(ms?: number | null): string {
  if (!ms || ms <= 0) return "0:00";
  const total = Math.round(ms / 1000);
  const m = Math.floor(total / 60);
  const s = total % 60;
  return `${m}:${s.toString().padStart(2, "0")}`;
}

export function MessageBubble({
  message,
  isOwn,
  showName = false,
  groupedWithPrev = false,
}: {
  message: ChatMessage;
  isOwn: boolean;
  /** Show sender name above bubble (group chats) — single chats can hide. */
  showName?: boolean;
  /** Compress vertical spacing when chained with the previous message. */
  groupedWithPrev?: boolean;
}) {
  const time = new Date(message.createdAt).toLocaleTimeString(undefined, {
    hour: "2-digit",
    minute: "2-digit",
  });

  if (message.type === "system") {
    return (
      <div className="my-3 flex justify-center">
        <span className="rounded-pill bg-surface-muted px-3 py-1 text-xs text-text-muted">
          {message.body}
        </span>
      </div>
    );
  }

  const isImage = message.type === "image" && message.mediaUrl;
  const isPdf = message.type === "file" && /pdf/i.test(message.mediaMime ?? "");

  return (
    <div
      className={cn(
        "flex w-full",
        isOwn ? "justify-end" : "justify-start",
        groupedWithPrev ? "mt-0.5" : "mt-2",
      )}
    >
      <div
        className={cn(
          "relative max-w-[78%] rounded-2xl px-3 py-2 shadow-sm",
          // WhatsApp-style tail tucked into the speaking corner.
          isOwn
            ? "bg-primary text-primary-contrast rounded-ee-md"
            : "bg-surface text-text border border-border rounded-es-md",
        )}
      >
        {showName && !isOwn && message.senderName && (
          <p className="mb-0.5 text-[11px] font-semibold text-accent">{message.senderName}</p>
        )}

        {message.type === "text" && (
          <p className="whitespace-pre-wrap break-words text-sm leading-relaxed">
            {message.body}
          </p>
        )}

        {isImage && (
          // eslint-disable-next-line @next/next/no-img-element -- private signed URL; not for next/image.
          <img
            src={message.mediaUrl ?? ""}
            alt=""
            className="max-h-72 rounded-md object-cover"
            loading="lazy"
          />
        )}

        {message.type === "voice" && (
          <div className="flex items-center gap-3 py-1 text-sm">
            <button
              type="button"
              className={cn(
                "grid h-9 w-9 place-items-center rounded-pill",
                isOwn ? "bg-white/20" : "bg-primary/10 text-primary",
              )}
              aria-label="play voice"
            >
              <Play className="h-4 w-4" />
            </button>
            <div className="flex flex-col">
              <span className="flex h-1 w-32 items-center gap-0.5">
                {Array.from({ length: 24 }).map((_, i) => (
                  <span
                    key={i}
                    className={cn(
                      "rounded-full",
                      isOwn ? "bg-white/60" : "bg-primary/60",
                    )}
                    style={{
                      width: 2,
                      height: 4 + ((i * 7) % 10),
                    }}
                  />
                ))}
              </span>
              <span className="text-[11px] opacity-80">
                {formatDuration(message.mediaDurationMs)}
              </span>
            </div>
          </div>
        )}

        {message.type === "file" && !isImage && (
          <a
            href={message.mediaUrl ?? "#"}
            target="_blank"
            rel="noopener noreferrer"
            className={cn(
              "flex items-center gap-3 rounded-md p-2 text-sm",
              isOwn ? "bg-white/15 hover:bg-white/25" : "bg-surface-muted hover:bg-surface-muted/80",
            )}
          >
            <span
              className={cn(
                "grid h-9 w-9 shrink-0 place-items-center rounded-md",
                isOwn ? "bg-white/20" : "bg-primary/10 text-primary",
              )}
            >
              {isPdf ? <FileText className="h-4 w-4" /> : <Paperclip className="h-4 w-4" />}
            </span>
            <div className="min-w-0 flex-1">
              <p className="truncate text-xs font-medium">
                {message.mediaName ?? message.body ?? "file"}
              </p>
              <p className="text-[11px] opacity-70">{formatSize(message.mediaSize)}</p>
            </div>
          </a>
        )}

        {message.type === "location" && (
          <div className="flex items-center gap-2 text-sm">
            <MapPin className="h-4 w-4" />
            <span>
              {message.latitude?.toFixed(4)}, {message.longitude?.toFixed(4)}
            </span>
          </div>
        )}

        <div
          className={cn(
            "mt-1 flex items-center justify-end gap-1 text-[10px]",
            isOwn ? "text-primary-contrast/80" : "text-text-muted",
          )}
        >
          <span>{time}</span>
          {isOwn && <ReadReceipt status={message.status} />}
        </div>
      </div>
    </div>
  );
}
