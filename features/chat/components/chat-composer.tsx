"use client";

import { useEffect, useRef, useState } from "react";
import { Send, Mic, Paperclip, Smile, X, FileText, ImageIcon } from "lucide-react";
import { EmojiPicker } from "./emoji-picker";
import { VoiceRecorder } from "./voice-recorder";

/**
 * Single accepted MIME prefix list. We keep PDFs, common images, and a few
 * document types — explicitly rejecting executables and archives.
 */
const ACCEPT = "image/*,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document";
const MAX_BYTES = 15 * 1024 * 1024; // 15 MB

export interface ComposerAttachment {
  file: File;
  kind: "image" | "file";
  previewUrl?: string;
}

interface Props {
  onSendText: (text: string) => void;
  onSendAttachment: (att: ComposerAttachment) => void;
  onSendVoice: (blob: Blob, durationMs: number) => void;
  placeholder?: string;
  disabled?: boolean;
}

export function ChatComposer({
  onSendText,
  onSendAttachment,
  onSendVoice,
  placeholder = "اكتب رسالة…",
  disabled = false,
}: Props) {
  const [draft, setDraft] = useState("");
  const [showEmoji, setShowEmoji] = useState(false);
  const [recording, setRecording] = useState(false);
  const [attachment, setAttachment] = useState<ComposerAttachment | null>(null);
  const [dragOver, setDragOver] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const taRef = useRef<HTMLTextAreaElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  // Auto-grow the textarea up to ~5 lines.
  useEffect(() => {
    const ta = taRef.current;
    if (!ta) return;
    ta.style.height = "auto";
    ta.style.height = Math.min(ta.scrollHeight, 120) + "px";
  }, [draft]);

  // Revoke object URLs to avoid leaks when the attachment is cleared.
  useEffect(() => {
    return () => {
      if (attachment?.previewUrl) URL.revokeObjectURL(attachment.previewUrl);
    };
  }, [attachment]);

  function handleFile(file: File | null | undefined) {
    if (!file) return;
    setError(null);
    if (file.size > MAX_BYTES) {
      setError("الملف كبير جدّاً (الحد ١٥MB)");
      return;
    }
    const isImage = file.type.startsWith("image/");
    setAttachment({
      file,
      kind: isImage ? "image" : "file",
      previewUrl: isImage ? URL.createObjectURL(file) : undefined,
    });
  }

  function send() {
    if (disabled) return;
    const text = draft.trim();
    if (attachment) {
      onSendAttachment(attachment);
      setAttachment(null);
    }
    if (text) {
      onSendText(text);
      setDraft("");
    }
  }

  function onKeyDown(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    // Enter to send, Shift+Enter for newline. Mobile keyboards send Enter as
    // newline anyway since the textarea doesn't trigger form submit on Enter
    // without us intercepting.
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      send();
    }
  }

  function onPaste(e: React.ClipboardEvent<HTMLTextAreaElement>) {
    const items = e.clipboardData?.items;
    if (!items) return;
    for (const item of Array.from(items)) {
      if (item.kind === "file") {
        const file = item.getAsFile();
        if (file) {
          e.preventDefault();
          handleFile(file);
          return;
        }
      }
    }
  }

  function onDrop(e: React.DragEvent) {
    e.preventDefault();
    setDragOver(false);
    const file = e.dataTransfer.files?.[0];
    if (file) handleFile(file);
  }

  if (recording) {
    return (
      <div className="border-t border-border bg-surface px-3 py-2">
        <VoiceRecorder
          onSend={(blob, ms) => {
            onSendVoice(blob, ms);
            setRecording(false);
          }}
          onCancel={() => setRecording(false)}
        />
      </div>
    );
  }

  return (
    <div
      onDragEnter={(e) => {
        e.preventDefault();
        setDragOver(true);
      }}
      onDragOver={(e) => {
        e.preventDefault();
        setDragOver(true);
      }}
      onDragLeave={() => setDragOver(false)}
      onDrop={onDrop}
      className={`relative border-t border-border bg-surface px-3 py-2 transition-colors ${
        dragOver ? "bg-primary/5" : ""
      }`}
    >
      {dragOver && (
        <div className="pointer-events-none absolute inset-2 grid place-items-center rounded-md border-2 border-dashed border-primary bg-primary/10 text-sm font-medium text-primary">
          أفلت الملف هنا للإرسال
        </div>
      )}

      {error && (
        <div className="mb-2 flex items-center justify-between rounded-md border border-danger/30 bg-danger/5 px-2 py-1 text-xs text-danger">
          <span>{error}</span>
          <button type="button" onClick={() => setError(null)} aria-label="إخفاء">
            <X className="h-3 w-3" />
          </button>
        </div>
      )}

      {attachment && (
        <div className="mb-2 flex items-center gap-3 rounded-md border border-border bg-surface-muted/40 p-2">
          {attachment.kind === "image" && attachment.previewUrl ? (
            // eslint-disable-next-line @next/next/no-img-element -- local object URL, not an asset.
            <img
              src={attachment.previewUrl}
              alt=""
              className="h-12 w-12 rounded-md object-cover"
            />
          ) : (
            <span className="grid h-12 w-12 place-items-center rounded-md bg-primary/10 text-primary">
              <FileText className="h-5 w-5" />
            </span>
          )}
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium">{attachment.file.name}</p>
            <p className="text-xs text-text-muted">
              {(attachment.file.size / 1024).toFixed(0)} KB
            </p>
          </div>
          <button
            type="button"
            onClick={() => setAttachment(null)}
            className="rounded-md p-1 text-text-muted hover:bg-surface-muted"
            aria-label="إلغاء المرفق"
          >
            <X className="h-4 w-4" />
          </button>
        </div>
      )}

      <div className="flex items-end gap-1">
        <div className="relative">
          <button
            type="button"
            onClick={() => setShowEmoji((s) => !s)}
            className="grid h-10 w-10 place-items-center rounded-md text-text-muted hover:bg-surface-muted"
            aria-label="emoji"
          >
            <Smile className="h-5 w-5" />
          </button>
          {showEmoji && (
            <div className="absolute bottom-full mb-2 start-0 z-30">
              <EmojiPicker
                onPick={(e) => {
                  setDraft((d) => d + e);
                  setShowEmoji(false);
                  taRef.current?.focus();
                }}
              />
            </div>
          )}
        </div>

        <button
          type="button"
          onClick={() => fileRef.current?.click()}
          className="grid h-10 w-10 place-items-center rounded-md text-text-muted hover:bg-surface-muted"
          aria-label="مرفق"
        >
          <Paperclip className="h-5 w-5" />
        </button>
        <input
          ref={fileRef}
          type="file"
          className="hidden"
          accept={ACCEPT}
          onChange={(e) => {
            handleFile(e.target.files?.[0]);
            e.target.value = "";
          }}
        />

        <textarea
          ref={taRef}
          rows={1}
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={onKeyDown}
          onPaste={onPaste}
          placeholder={placeholder}
          disabled={disabled}
          className="max-h-[120px] flex-1 resize-none rounded-2xl border border-border bg-surface px-3 py-2 text-text outline-none focus:border-primary disabled:opacity-50"
        />

        {draft.trim() || attachment ? (
          <button
            type="button"
            onClick={send}
            disabled={disabled}
            className="grid h-10 w-10 place-items-center rounded-pill bg-primary text-primary-contrast hover:bg-primary-hover disabled:opacity-50"
            aria-label="إرسال"
          >
            <Send className="h-4 w-4 rtl:rotate-180" />
          </button>
        ) : (
          <button
            type="button"
            onClick={() => setRecording(true)}
            disabled={disabled}
            className="grid h-10 w-10 place-items-center rounded-pill bg-primary text-primary-contrast hover:bg-primary-hover disabled:opacity-50"
            aria-label="تسجيل صوتي"
          >
            <Mic className="h-4 w-4" />
          </button>
        )}
      </div>
    </div>
  );
}

// Re-export so importers can keep one source.
export { ImageIcon };
