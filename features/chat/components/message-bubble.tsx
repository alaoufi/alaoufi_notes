import { cn } from "@syanah/ui";
import { MapPin, Mic, Paperclip } from "lucide-react";
import type { ChatMessage } from "../types";

export function MessageBubble({
  message,
  isOwn,
}: {
  message: ChatMessage;
  isOwn: boolean;
}) {
  const time = new Date(message.createdAt).toLocaleTimeString(undefined, {
    hour: "2-digit",
    minute: "2-digit",
  });

  if (message.type === "system") {
    return (
      <div className="my-2 flex justify-center">
        <span className="rounded-pill bg-surface-muted px-3 py-1 text-xs text-text-muted">
          {message.body}
        </span>
      </div>
    );
  }

  return (
    <div
      className={cn(
        "flex w-full",
        isOwn ? "justify-end" : "justify-start",
      )}
    >
      <div
        className={cn(
          "max-w-[78%] rounded-lg px-3 py-2 shadow-sm",
          isOwn
            ? "bg-primary text-primary-contrast"
            : "bg-surface text-text border border-border",
        )}
      >
        {message.type === "text" && <p className="whitespace-pre-wrap break-words">{message.body}</p>}
        {message.type === "image" && message.mediaUrl && (
          // eslint-disable-next-line @next/next/no-img-element -- chat media is private and uses signed URLs; not an asset next/image can pre-optimize.
          <img src={message.mediaUrl} alt="" className="max-h-72 rounded-md" />
        )}
        {message.type === "voice" && (
          <div className="flex items-center gap-2 text-sm">
            <Mic className="h-4 w-4" />
            <span>
              {Math.round((message.mediaDurationMs ?? 0) / 1000)}s
            </span>
          </div>
        )}
        {message.type === "file" && (
          <div className="flex items-center gap-2 text-sm">
            <Paperclip className="h-4 w-4" />
            <span className="break-all">{message.body ?? "file"}</span>
          </div>
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
            "mt-1 text-end text-[10px]",
            isOwn ? "text-primary-contrast/70" : "text-text-muted",
          )}
        >
          {time}
        </div>
      </div>
    </div>
  );
}
