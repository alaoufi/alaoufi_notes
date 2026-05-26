"use client";

import { useEffect, useRef, useState } from "react";
import { Mic, Square, Send, Trash2 } from "lucide-react";

interface Props {
  onSend: (blob: Blob, durationMs: number) => void;
  onCancel: () => void;
}

/**
 * Tap-and-hold-free recorder: one button to start, one to stop, then send/cancel.
 * Uses MediaRecorder with audio/webm where supported; falls back to default mime.
 */
export function VoiceRecorder({ onSend, onCancel }: Props) {
  const [phase, setPhase] = useState<"idle" | "recording" | "review">("idle");
  const [elapsed, setElapsed] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const blobRef = useRef<Blob | null>(null);
  const recorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const streamRef = useRef<MediaStream | null>(null);
  const tickRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const startedAt = useRef<number>(0);

  useEffect(() => {
    // Kick off recording immediately on mount.
    void start();
    return () => {
      stopTick();
      stopStream();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function stopTick() {
    if (tickRef.current) {
      clearInterval(tickRef.current);
      tickRef.current = null;
    }
  }
  function stopStream() {
    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;
  }

  async function start() {
    setError(null);
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;
      const mime = MediaRecorder.isTypeSupported("audio/webm;codecs=opus")
        ? "audio/webm;codecs=opus"
        : MediaRecorder.isTypeSupported("audio/webm")
          ? "audio/webm"
          : "";
      const rec = mime ? new MediaRecorder(stream, { mimeType: mime }) : new MediaRecorder(stream);
      chunksRef.current = [];
      rec.ondataavailable = (e) => {
        if (e.data && e.data.size > 0) chunksRef.current.push(e.data);
      };
      rec.onstop = () => {
        const blob = new Blob(chunksRef.current, { type: rec.mimeType || "audio/webm" });
        blobRef.current = blob;
        setPhase("review");
        stopStream();
      };
      rec.start();
      recorderRef.current = rec;
      setPhase("recording");
      startedAt.current = Date.now();
      setElapsed(0);
      tickRef.current = setInterval(() => {
        setElapsed(Math.floor((Date.now() - startedAt.current) / 1000));
      }, 200);
    } catch {
      setError("denied");
      setPhase("idle");
    }
  }

  function stopRecording() {
    stopTick();
    recorderRef.current?.stop();
  }

  function discard() {
    stopTick();
    stopStream();
    blobRef.current = null;
    onCancel();
  }

  function confirm() {
    if (!blobRef.current) return;
    onSend(blobRef.current, elapsed * 1000);
  }

  const mm = Math.floor(elapsed / 60).toString().padStart(2, "0");
  const ss = (elapsed % 60).toString().padStart(2, "0");

  if (error === "denied") {
    return (
      <div className="flex h-12 items-center justify-between gap-2 rounded-md border border-danger/40 bg-danger/5 px-3 text-sm text-danger">
        <span>الميكروفون غير مسموح. فعّل الإذن من إعدادات المتصفّح.</span>
        <button type="button" onClick={onCancel} className="text-xs underline">
          إلغاء
        </button>
      </div>
    );
  }

  return (
    <div className="flex h-12 items-center gap-3 rounded-md border border-border bg-surface-muted/40 px-3">
      <span className="grid h-9 w-9 place-items-center rounded-pill bg-danger/15 text-danger">
        <Mic className="h-4 w-4 animate-pulse" />
      </span>
      <span className="font-mono text-sm tabular-nums text-text">
        {mm}:{ss}
      </span>
      <span className="flex-1 text-xs text-text-muted">
        {phase === "recording" ? "يتم التسجيل…" : "اضغط لإرسال التسجيل"}
      </span>
      <button
        type="button"
        onClick={discard}
        className="grid h-9 w-9 place-items-center rounded-md text-danger hover:bg-danger/10"
        aria-label="إلغاء"
      >
        <Trash2 className="h-4 w-4" />
      </button>
      {phase === "recording" ? (
        <button
          type="button"
          onClick={stopRecording}
          className="grid h-9 w-9 place-items-center rounded-md bg-primary text-primary-contrast hover:bg-primary-hover"
          aria-label="إيقاف"
        >
          <Square className="h-4 w-4" />
        </button>
      ) : (
        <button
          type="button"
          onClick={confirm}
          className="grid h-9 w-9 place-items-center rounded-md bg-primary text-primary-contrast hover:bg-primary-hover"
          aria-label="إرسال"
        >
          <Send className="h-4 w-4 rtl:rotate-180" />
        </button>
      )}
    </div>
  );
}
