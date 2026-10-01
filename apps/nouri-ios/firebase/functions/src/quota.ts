import "./admin";
import { getFirestore } from "firebase-admin/firestore";
import { defineInt } from "firebase-functions/params";
import { HttpsError } from "firebase-functions/v2/https";
import { consume, limitMessage, refund, type QuotaKind, type QuotaState } from "./quotaLogic";

// Daily per-user limits. To change them without touching code, set e.g. MEAL_PHOTO_DAILY_LIMIT=15 in
// functions/.env (or .env.<project-id>) and redeploy.
export const DAILY_LIMITS: Record<QuotaKind, ReturnType<typeof defineInt>> = {
  mealPhoto: defineInt("MEAL_PHOTO_DAILY_LIMIT", { default: 12, description: "Meal photos analysed per user per UTC day" }),
  label: defineInt("LABEL_DAILY_LIMIT", { default: 10, description: "Product/care labels read per user per UTC day" }),
  report: defineInt("REPORT_DAILY_LIMIT", { default: 3, description: "Blood work reports read per user per UTC day" }),
};

const doc = (uid: string) => getFirestore().collection("rateLimits").doc(uid);

/** Takes one unit for `uid` or throws `resource-exhausted`. Call before the Claude request. */
export async function takeQuota(uid: string, kind: QuotaKind): Promise<{ remaining: number; limit: number }> {
  const limit = DAILY_LIMITS[kind].value();
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
