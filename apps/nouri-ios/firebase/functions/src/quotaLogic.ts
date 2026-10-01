// Pure per-user daily quota logic — no Firebase imports, so it's unit-testable.

export type QuotaKind = "mealPhoto" | "label" | "report";

/** Stored at rateLimits/{uid} (clients can't read or write it; see firestore.rules). */
export interface QuotaState {
  /** UTC day the counts belong to, YYYY-MM-DD. */
  day: string;
  counts: Partial<Record<QuotaKind, number>>;
}

export interface QuotaDecision {
  allowed: boolean;
  next: QuotaState;
  used: number;
  remaining: number;
}

export function utcDay(now: Date): string {
  return now.toISOString().slice(0, 10);
}

/** Takes one unit of `kind` for today if under `limit`; counts reset when the UTC day changes. */
export function consume(state: QuotaState | undefined, kind: QuotaKind, limit: number, now: Date): QuotaDecision {
  const day = utcDay(now);
  const counts = state && state.day === day ? { ...state.counts } : {};
  const used = counts[kind] ?? 0;
  if (used >= limit) {
    return { allowed: false, next: { day, counts }, used, remaining: 0 };
  }
  counts[kind] = used + 1;
  return { allowed: true, next: { day, counts }, used: used + 1, remaining: limit - used - 1 };
}

/** Gives a unit back (the request failed on our side). Never goes below zero or touches another day. */
export function refund(state: QuotaState | undefined, kind: QuotaKind, now: Date): QuotaState | undefined {
  if (!state || state.day !== utcDay(now)) return state;
  const counts = { ...state.counts, [kind]: Math.max(0, (state.counts[kind] ?? 0) - 1) };
  return { day: state.day, counts };
}

const NOUN: Record<QuotaKind, [string, string]> = {
  mealPhoto: ["meal photo", "log meals by typing the ingredients"],
  label: ["label scan", "add products by typing their ingredients"],
  report: ["report upload", "enter results by hand"],
};

export function limitMessage(kind: QuotaKind, limit: number): string {
  const [noun, fallback] = NOUN[kind];
  return `You've reached today's limit of ${limit} ${noun}s. You can still ${fallback}; the limit resets at midnight UTC.`;
}
