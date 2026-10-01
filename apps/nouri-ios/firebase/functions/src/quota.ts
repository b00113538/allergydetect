import "./admin";
import { getFirestore } from "firebase-admin/firestore";
import { defineInt } from "firebase-functions/params";
import { HttpsError } from "firebase-functions/v2/https";
import { consume, limitMessage, planFor, refund, type Plan, type QuotaKind, type QuotaState } from "./quotaLogic";

// Daily per-user limits. To change them without touching code, set e.g. MEAL_PHOTO_DAILY_LIMIT=15 in
// functions/.env (or .env.<project-id>) and redeploy.
export const DAILY_LIMITS: Record<Plan, Record<QuotaKind, ReturnType<typeof defineInt>>> = {
  free: {
    mealPhoto: defineInt("MEAL_PHOTO_DAILY_LIMIT", { default: 12, description: "Free plan: meal photos per user per UTC day" }),
    label: defineInt("LABEL_DAILY_LIMIT", { default: 10, description: "Free plan: product/care labels per user per UTC day" }),
    report: defineInt("REPORT_DAILY_LIMIT", { default: 3, description: "Free plan: blood work reports per user per UTC day" }),
  },
  premium: {
    mealPhoto: defineInt("PREMIUM_MEAL_PHOTO_DAILY_LIMIT", { default: 30, description: "Premium: meal photos per user per UTC day" }),
    label: defineInt("PREMIUM_LABEL_DAILY_LIMIT", { default: 30, description: "Premium: product/care labels per user per UTC day" }),
    report: defineInt("PREMIUM_REPORT_DAILY_LIMIT", { default: 10, description: "Premium: blood work reports per user per UTC day" }),
  },
};

const doc = (uid: string) => getFirestore().collection("rateLimits").doc(uid);

/**
 * Takes one unit for `uid` or throws `resource-exhausted`. Call before the Claude request.
 * `token` is the caller's decoded ID token (request.auth.token); its `plan` claim picks the limits.
 */
export async function takeQuota(uid: string, kind: QuotaKind, token?: Record<string, unknown>): Promise<{ remaining: number; limit: number }> {
  const limit = DAILY_LIMITS[planFor(token)][kind].value();
  const decision = await getFirestore().runTransaction(async (tx) => {
    const snap = await tx.get(doc(uid));
    const result = consume(snap.data() as QuotaState | undefined, kind, limit, new Date());
    if (result.allowed) tx.set(doc(uid), result.next);
    return result;
  });
  if (!decision.allowed) throw new HttpsError("resource-exhausted", limitMessage(kind, limit));
  return { remaining: decision.remaining, limit };
}

/** Returns a unit when the request failed on our side (Claude error, bad output), so users aren't charged for it. */
export async function returnQuota(uid: string, kind: QuotaKind): Promise<void> {
  try {
    await getFirestore().runTransaction(async (tx) => {
      const snap = await tx.get(doc(uid));
      const next = refund(snap.data() as QuotaState | undefined, kind, new Date());
      if (next) tx.set(doc(uid), next);
    });
  } catch {
    // Best effort: a missed refund only costs the user one unit for today.
  }
}

/** Runs `work` and gives the unit back if it throws. */
export async function withRefund<T>(uid: string, kind: QuotaKind, work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (err) {
    await returnQuota(uid, kind);
    throw err;
  }
}
