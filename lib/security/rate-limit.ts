/**
 * In-memory token-bucket rate limiter.
 *
 * Good enough for a single Vercel instance / per-edge-region. Once we have
 * Redis (Upstash recommended on Vercel) swap the Map for the durable store.
 * The API surface stays the same.
 */

interface Bucket {
  tokens: number;
  updatedAt: number;
}

const STORE = new Map<string, Bucket>();
const SWEEP_AFTER = 1000 * 60 * 30; // drop entries idle >30min

function sweep() {
  const cutoff = Date.now() - SWEEP_AFTER;
  for (const [k, v] of STORE) {
    if (v.updatedAt < cutoff) STORE.delete(k);
  }
}

export interface RateLimitOptions {
  /** Distinct namespace per route family so a chat limit doesn't burn order limit. */
  namespace: string;
  /** Maximum requests permitted in the rolling window. */
  max: number;
  /** Window size in milliseconds. */
  windowMs: number;
}

export interface RateLimitResult {
  ok: boolean;
  remaining: number;
  resetMs: number;
}

/**
 * Consume one token. Returns ok=false when the bucket is empty.
 * Use the IP, user id, or a composite as the identifier.
 */
export function checkRateLimit(
  identifier: string,
  opts: RateLimitOptions,
): RateLimitResult {
  if (STORE.size > 5000) sweep();

  const key = `${opts.namespace}:${identifier}`;
  const now = Date.now();
  const existing = STORE.get(key);

  // Token-bucket refill rate: full bucket per windowMs.
  const refillPerMs = opts.max / opts.windowMs;

  let tokens: number;
  if (!existing) {
    tokens = opts.max;
  } else {
    const elapsed = now - existing.updatedAt;
    tokens = Math.min(opts.max, existing.tokens + elapsed * refillPerMs);
  }

  if (tokens < 1) {
    STORE.set(key, { tokens, updatedAt: now });
    const resetMs = Math.ceil((1 - tokens) / refillPerMs);
    return { ok: false, remaining: 0, resetMs };
  }

  tokens -= 1;
  STORE.set(key, { tokens, updatedAt: now });
  return { ok: true, remaining: Math.floor(tokens), resetMs: 0 };
}

/** Best-effort client identifier — IP from common forwarded headers. */
export function clientIdFromHeaders(headers: Headers, fallback = "anon"): string {
  return (
    headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    headers.get("x-real-ip") ||
    headers.get("cf-connecting-ip") ||
    fallback
  );
}
