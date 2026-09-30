import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, Timestamp, type DocumentReference } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {
  type DeviceDoc,
  type PushMessage,
  dailyReminderMessage,
  isReaction,
  likelyTriggers,
  localWeekday,
  startOfLocalDay,
  weeklySummaryMessage,
} from "./pushLogic";

if (getApps().length === 0) initializeApp();

const DAY_MS = 24 * 3600 * 1000;

interface Device {
  ref: DocumentReference;
  token: string;
  data: DeviceDoc;
}

/**
 * Runs at the top of every hour. For each device whose chosen reminder hour is now:
 *  - on the user's local Sunday, sends the weekly summary (if enabled);
 *  - otherwise, if nothing at all has been logged since local midnight, sends the evening reminder
 *    (if enabled). Users who have logged something today are left alone.
 * Post-meal check-ins stay as on-device local notifications, which work offline.
 */
export const sendScheduledPushes = onSchedule(
  { schedule: "0 * * * *", timeZone: "Etc/UTC", region: "us-central1", timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    const db = getFirestore();
    const now = new Date();
    const snapshot = await db.collectionGroup("devices").where("reminderUtcHour", "==", now.getUTCHours()).get();

    const byUser = new Map<string, Device[]>();
    for (const doc of snapshot.docs) {
      const uid = doc.ref.parent.parent?.id;
      if (!uid) continue;
      const list = byUser.get(uid) ?? [];
      list.push({ ref: doc.ref, token: doc.id, data: doc.data() as DeviceDoc });
      byUser.set(uid, list);
    }

    let sent = 0;
    for (const [uid, devices] of byUser) {
      try {
        sent += await handleUser(uid, devices, now);
      } catch (err) {
        logger.error("Push job failed for user", { uid, err: String(err) });
      }
    }
    logger.info("Scheduled pushes done", { users: byUser.size, sent });
  },
);

async function handleUser(uid: string, devices: Device[], now: Date): Promise<number> {
  const db = getFirestore();
  const user = db.collection("users").doc(uid);
  const offset = devices[0].data.utcOffsetMinutes ?? 0;
  let sent = 0;

  const isSunday = localWeekday(now, offset) === 0;
  const weekly = isSunday ? devices.filter((d) => d.data.weeklySummary) : [];
  if (weekly.length > 0) {
    const since = Timestamp.fromDate(new Date(now.getTime() - 7 * DAY_MS));
    const [meals, symptoms, profile] = await Promise.all([
      user.collection("meals").where("timestamp", ">=", since).count().get(),
      user.collection("symptoms").where("timestamp", ">=", since).select("symptomTypes").get(),
      user.collection("profile").doc("current").get(),
    ]);
    const triggers = likelyTriggers(profile.data());
    const message = weeklySummaryMessage({
      mealsLogged: meals.data().count,
      reactions: symptoms.docs.filter((d) => isReaction(d.get("symptomTypes"))).length,
      topTrigger: triggers[0],
      likelyTriggerCount: triggers.length,
    });
    sent += await send(weekly, message);
  }

  // One notification per device per evening: the weekly summary replaces the reminder on Sundays.
  const daily = devices.filter((d) => d.data.dailyReminder && !weekly.includes(d));
  if (daily.length > 0) {
    const since = Timestamp.fromDate(startOfLocalDay(now, offset));
    const logged = await Promise.all(
      ["meals", "symptoms", "skinLogs"].map((c) => user.collection(c).where("timestamp", ">=", since).limit(1).get()),
    );
    if (logged.every((s) => s.empty)) sent += await send(daily, dailyReminderMessage());
  }
  return sent;
}

/** Sends to the given devices and deletes any whose token FCM reports as dead. */
async function send(devices: Device[], message: PushMessage): Promise<number> {
  const response = await getMessaging().sendEachForMulticast({
    tokens: devices.map((d) => d.token),
    notification: { title: message.title, body: message.body },
    data: { route: message.route },
    apns: { payload: { aps: { sound: "default" } } },
  });
  const stale: Promise<unknown>[] = [];
  response.responses.forEach((r, i) => {
    const code = r.error?.code;
    if (code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token") {
      stale.push(devices[i].ref.delete());
    } else if (r.error) {
      logger.warn("Push failed", { code, message: r.error.message });
    }
  });
  await Promise.all(stale);
  return response.successCount;
}
