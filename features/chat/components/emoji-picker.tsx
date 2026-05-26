"use client";

/**
 * Small dependency-free emoji picker — a curated palette covering the most
 * common chat reactions and Arabic-friendly faces. If we ever need full
 * Unicode coverage, swap in emoji-mart, but this keeps the bundle small.
 */
const EMOJI_GROUPS: Array<{ name: string; emoji: string[] }> = [
  {
    name: "smileys",
    emoji: ["😀","😃","😄","😁","😆","😅","😂","🤣","🙂","😊","😇","🥰","😍","😘","😗","🤗","🤩","🤔","😐","😑","😶","🙄","😏","😴","🤤","😪","🥱","😵"],
  },
  {
    name: "gestures",
    emoji: ["👍","👎","👏","🙏","🙌","🤝","👌","✌️","🤞","🤟","🤘","✊","👊","👋","🫡","🫶","💪","👇","👆","☝️","👉","👈"],
  },
  {
    name: "hearts",
    emoji: ["❤️","🧡","💛","💚","💙","💜","🖤","🤍","🤎","💔","❣️","💕","💞","💓","💗","💖","💘","💝"],
  },
  {
    name: "objects",
    emoji: ["🔧","🛠️","⚙️","🔨","🪛","🧰","🔌","💡","🚿","🚰","🚪","🏠","🏡","🚗","🚙","🏍️","🚲","📞","📱","💬","📷","📍","✅","❌","⏰","🔥","💧","⚡","❄️","☀️"],
  },
];

export function EmojiPicker({ onPick }: { onPick: (emoji: string) => void }) {
  return (
    <div className="max-h-64 w-72 overflow-y-auto rounded-lg border border-border bg-surface p-2 shadow-lg">
      {EMOJI_GROUPS.map((g) => (
        <div key={g.name} className="mb-2 last:mb-0">
          <div className="grid grid-cols-8 gap-1">
            {g.emoji.map((e) => (
              <button
                key={e}
                type="button"
                onClick={() => onPick(e)}
                className="grid h-8 w-8 place-items-center rounded-md text-lg hover:bg-surface-muted"
                aria-label={e}
              >
                {e}
              </button>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}
