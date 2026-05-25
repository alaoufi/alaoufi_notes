"use client";

import { useEffect, useRef, useState } from "react";
import { Send, MapPin, Mic, Paperclip } from "lucide-react";
import { Button } from "@syanah/ui";
import { MessageBubble } from "./message-bubble";
import type { ChatMessage } from "../types";

const SAMPLE_OWN_ID = "u-me";
const SAMPLE_OTHER_ID = "u-them";

const initial: ChatMessage[] = [
  {
    id: "m1",
    type: "system",
    body: "تمّ إنشاء الطلب وانتظار قبول المزوّد.",
    senderId: "system",
    createdAt: new Date(Date.now() - 1000 * 60 * 30).toISOString(),
  },
  {
    id: "m2",
    type: "text",
    body: "السلام عليكم، الطلب وصلني وأنا في طريقي خلال 20 دقيقة.",
    senderId: SAMPLE_OTHER_ID,
    senderName: "Ahmed",
    createdAt: new Date(Date.now() - 1000 * 60 * 25).toISOString(),
  },
  {
    id: "m3",
    type: "text",
    body: "وعليكم السلام، تمام. الموقع يظهر في الخريطة، هل تحتاج شيء؟",
    senderId: SAMPLE_OWN_ID,
    createdAt: new Date(Date.now() - 1000 * 60 * 24).toISOString(),
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

export function ChatThread({ archived = false }: { archived?: boolean }) {
  const [messages, setMessages] = useState<ChatMessage[]>(initial);
  const [draft, setDraft] = useState("");
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages.length]);

  function send(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const text = draft.trim();
    if (!text || archived) return;
    setMessages((prev) => [
      ...prev,
      {
        id: `m-${prev.length + 1}`,
        type: "text",
        body: text,
        senderId: SAMPLE_OWN_ID,
        createdAt: new Date().toISOString(),
      },
    ]);
    setDraft("");
  }

  return (
    <div className="flex h-[560px] flex-col overflow-hidden rounded-lg border border-border bg-bg">
      <div className="flex-1 space-y-2 overflow-y-auto px-4 py-3">
        {messages.map((m) => (
          <MessageBubble key={m.id} message={m} isOwn={m.senderId === SAMPLE_OWN_ID} />
        ))}
        <div ref={endRef} />
      </div>

      {archived ? (
        <div className="border-t border-border bg-surface-muted/40 px-4 py-3 text-center text-sm text-text-muted">
          أُرشِفَت هذه المحادثة. للقراءة فقط.
        </div>
      ) : (
        <form
          onSubmit={send}
          className="flex items-center gap-2 border-t border-border bg-surface px-3 py-2"
        >
          <button
            type="button"
            className="grid h-10 w-10 place-items-center rounded-md text-text-muted hover:bg-surface-muted"
            aria-label="attach"
          >
            <Paperclip className="h-5 w-5" />
          </button>
          <button
            type="button"
            className="grid h-10 w-10 place-items-center rounded-md text-text-muted hover:bg-surface-muted"
            aria-label="location"
          >
            <MapPin className="h-5 w-5" />
          </button>
          <button
            type="button"
            className="grid h-10 w-10 place-items-center rounded-md text-text-muted hover:bg-surface-muted"
            aria-label="voice"
          >
            <Mic className="h-5 w-5" />
          </button>
          <input
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            placeholder="اكتب رسالة..."
            className="h-10 flex-1 rounded-md border border-border bg-surface px-3 text-text outline-none focus:border-primary"
          />
          <Button type="submit" size="sm" iconStart={<Send className="h-4 w-4 rtl:rotate-180" />}>
            إرسال
          </Button>
        </form>
      )}
    </div>
  );
}
