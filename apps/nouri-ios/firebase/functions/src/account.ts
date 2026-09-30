import "./admin";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

/**
 * Callable: permanently deletes the signed-in user's account and everything stored for it —
 * required by App Store Review Guideline 5.1.1(v) for apps that let people create an account.
 *   - users/{uid} and every subcollection (meals, symptoms, skin logs, blood work, profile,
 *     private Dine Code records, push devices)
 *   - public dineCodes/{token} snapshots owned by the user (so printed QR codes stop working)
 *   - Cloud Storage files under users/{uid}/ (meal/skin photos, blood work reports)
 *   - the Firebase Auth user
 * Order matters: data first, auth last, so a failure part-way can be retried by the still-signed-in user.
 */
export const deleteAccount = onCall({ region: "us-central1", timeoutSeconds: 300 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to delete your account.");
  }
  const uid = request.auth.uid;
  const db = getFirestore();

  try {
    const codes = await db.collection("dineCodes").where("ownerUid", "==", uid).get();
    await Promise.all(codes.docs.map((doc) => doc.ref.delete()));
    await db.recursiveDelete(db.collection("users").doc(uid));
    await getStorage().bucket().deleteFiles({ prefix: `users/${uid}/` });
    await getAuth().deleteUser(uid);
  } catch (err) {
    logger.error("Account deletion failed", { uid, err: String(err) });
    throw new HttpsError("internal", "Your account couldn't be fully deleted. Please try again.");
  }

  logger.info("Account deleted", { uid });
  return { deleted: true };
});
