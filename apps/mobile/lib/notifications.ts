import * as Notifications from "expo-notifications";
import { Platform } from "react-native";

import type { Router } from "expo-router";

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

export async function registerForPush(): Promise<string | null> {
  const { status: existing } = await Notifications.getPermissionsAsync();
  let status = existing;
  if (existing !== "granted") {
    const req = await Notifications.requestPermissionsAsync();
    status = req.status;
  }
  if (status !== "granted") return null;
  try {
    const token = await Notifications.getExpoPushTokenAsync();
    return token.data;
  } catch {
    return null;
  }
}

export async function scheduleMealFollowUp(mealName: string, mealId: string): Promise<void> {
  await Notifications.scheduleNotificationAsync({
    content: {
      title: "How are you feeling?",
      body: `You ate ${mealName} 45 minutes ago. Any symptoms to log?`,
      data: { type: "symptom_checkin", meal_id: mealId },
      sound: true,
    },
    trigger: { seconds: 45 * 60 },
  });
}

export async function scheduleDailyReminder(hour: number, minute: number): Promise<void> {
  await Notifications.scheduleNotificationAsync({
    content: {
      title: "Time to log your meals",
      body: "Keep your health data complete for better allergy insights.",
      data: { type: "daily_reminder" },
    },
    trigger: { hour, minute, repeats: true },
  });
}

export async function scheduleEliminationReminder(ingredient: string, day: number): Promise<void> {
  await Notifications.scheduleNotificationAsync({
    content: {
      title: `Elimination test — day ${day}`,
      body: `Day ${day} of avoiding ${ingredient}. Keep going!`,
      data: { type: "elimination" },
    },
    trigger: { seconds: 24 * 60 * 60, repeats: true },
  });
}

export function setupNotificationHandler(router: Router): () => void {
  const sub = Notifications.addNotificationResponseReceivedListener((response) => {
    const data = response.notification.request.content.data as { type?: string };
    switch (data.type) {
      case "symptom_checkin":
        router.push("/(tabs)/symptoms");
        break;
      case "allergen_insight":
        router.push("/(tabs)/insights");
        break;
      case "daily_reminder":
        router.push("/(tabs)/scan");
        break;
      case "weekly_report":
        router.push("/reports/weekly");
        break;
      default:
        break;
    }
  });
  return () => sub.remove();
}

export const isAndroid = Platform.OS === "android";
