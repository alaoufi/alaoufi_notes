"use client";

import { useEffect, useRef, useState } from "react";
import { MessageBubble } from "./message-bubble";
import { ChatComposer, type ComposerAttachment } from "./chat-composer";
import type { ChatMessage } from "../types";

const SAMPLE_OWN_ID = "u-me";
const SAMPLE_OTHER_ID = "u-them";

const initial: ChatMessage[] = [
  {
    id: "m1",
    type: "system",
    body: "تمّ إنشاء الطلب وانتظار قبول المزوّد.",
    senderId: "system",
    createdAt: new Date(Date.now() - 1000 * 60 * 60 * 26).toISOString(),
  },
  {
    id: "m2",
    type: "text",
    body: "السلام عليكم، الطلب وصلني وأنا في طريقي خلال 20 دقيقة.",
    senderId: SAMPLE_OTHER_ID,
    senderName: "أحمد",
    createdAt: new Date(Date.now() - 1000 * 60 * 25).toISOString(),
  },
  {
    id: "m3",
    type: "text",
    body: "وعليكم السلام، تمام. الموقع يظهر في الخريطة، هل تحتاج شيء؟",
    senderId: SAMPLE_OWN_ID,
    createdAt: new Date(Date.now() - 1000 * 60 * 24).toISOString(),
    status: "read",
  },
  {
    id: "m4",
    type: "location",
    senderId: SAMPLE_OTHER_ID,
    latitude: 24.7136,
    longitude: 46.6753,
    createdAt: new Date(Date.now() - 1000 * 60 * 20).toISOString(),
  },
  {
    id: "m5",
    type: "voice",
    senderId: SAMPLE_OTHER_ID,
    mediaDurationMs: 12000,
    createdAt: new Date(Date.now() - 1000 * 60 * 18).toISOString(),
  },
];

function dayLabel(iso: string): string {
  const d = new Date(iso);
  const today = new Date();
  const yesterday = new Date(Date.now() - 86400000);
  if (d.toDateString() === today.toDateString()) return "اليوم";
  if (d.toDateString() === yesterday.toDateString()) return "أمس";
  return d.toLocaleDateString("ar-SA", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

export function ChatThread({ archived = false }: { archived?: boolean }) {
  const [messages, setMessages] = useState<ChatMessage[]>(initial);
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages.length]);

  function sendText(text: string) {
    if (archived) return;
    setMessages((prev) => [
      ...prev,
      {
        id: `m-${Date.now()}`,
        type: "text",
        body: text,
        senderId: SAMPLE_OWN_ID,
        createdAt: new Date().toISOString(),        status: "sent",
      },
    ]);
  }

  function sendAttachment(att: ComposerAttachment) {
    if (archived) return;
    setMessages((prev) => [
      ...prev,
      {
        id: `m-${Date.now()}`,
        type: att.kind === "image" ? "image" : "file",
        senderId: SAMPLE_OWN_ID,
        createdAt: new Date().toISOString(),
        mediaUrl: att.previewUrl ?? null,
        mediaMime: att.file.type,
        mediaName: att.file.name,
        mediaSize: att.file.size,
        status: "sending",
      },
    ]);
  }

  function sendVoice(blob: Blob, durationMs: number) {
    if (archived) return;
    setMessages((prev) => [
      ...prev,
      {
        id: `m-${Date.now()}`,
        type: "voice",
        senderId: SAMPLE_OWN_ID,
        createdAt: new Date().toISOString(),
        mediaUrl: URL.createObjectURL(blob),
        mediaMime: blob.type,
        mediaDurationMs: durationMs,
        status: "sending",
      },
    ]);
  }

  // Group consecutive same-sender messages and insert day separators.
  const rendered: React.ReactNode[] = [];
  let prevDay: string | null = null;
  let prevSender: string | null = null;
  for (const m of messages) {
    const day = new Date(m.createdAt).toDateString();
    if (day !== prevDay) {
      rendered.push(
        <div key={`day-${day}`} className="my-3 flex justify-center">
          <span className="rounded-pill bg-surface-muted px-3 py-1 text-[11px] font-medium text-text-muted">
            {dayLabel(m.createdAt)}
          </span>
        </div>,
      );
      prevDay = day;
      prevSender = null;
    }
    const grouped = m.senderId === prevSender && m.type !== "system";
    rendered.push(
      <MessageBubble
        key={m.id}
        message={m}
        isOwn={m.senderId === SAMPLE_OWN_ID}
        groupedWithPrev={grouped}
      />,
    );
    prevSender = m.senderId;
  }

  return (
    <div className="flex h-[600px] flex-col overflow-hidden rounded-lg border border-border bg-bg">
      <div className="flex-1 overflow-y-auto px-3 py-3 sm:px-4">
        {rendered}
        <div ref={endRef} />
      </div>

      {archived ? (
        <div className="border-t border-border bg-surface-muted/40 px-4 py-3 text-center text-sm text-text-muted">
          أُرشِفَت هذه المحادثة. للقراءة فقط.
        </div>
      ) : (
        <ChatComposer
          onSendText={sendText}
          onSendAttachment={sendAttachment}
          onSendVoice={sendVoice}
        />
      )}
    </div>
  );
}
