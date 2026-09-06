import AsyncStorage from "@react-native-async-storage/async-storage";
import * as SecureStore from "expo-secure-store";
import { Platform } from "react-native";

import type { CreateFoodLogRequest } from "@/types";

const ACCESS_KEY = "ad_access_token";
const REFRESH_KEY = "ad_refresh_token";
const OFFLINE_QUEUE = "offline_queue";

// SecureStore has no web implementation. On web we fall back to AsyncStorage
// (which is localStorage under the hood) — acceptable for a dev preview only.
const isWeb = Platform.OS === "web";

async function setSecure(key: string, value: string) {
  if (isWeb) await AsyncStorage.setItem(key, value);
  else await SecureStore.setItemAsync(key, value);
}

async function getSecure(key: string): Promise<string | null> {
  if (isWeb) return AsyncStorage.getItem(key);
  return SecureStore.getItemAsync(key);
}

async function deleteSecure(key: string) {
  if (isWeb) await AsyncStorage.removeItem(key);
  else await SecureStore.deleteItemAsync(key);
}

export const tokenStore = {
  async setTokens(access: string, refresh: string) {
    await setSecure(ACCESS_KEY, access);
    await setSecure(REFRESH_KEY, refresh);
  },
  async setAccess(access: string) {
    await setSecure(ACCESS_KEY, access);
  },
  async getAccess() {
    return getSecure(ACCESS_KEY);
  },
  async getRefresh() {
    return getSecure(REFRESH_KEY);
  },
  async clear() {
    await deleteSecure(ACCESS_KEY);
    await deleteSecure(REFRESH_KEY);
  },
};

async function getArray<T>(key: string): Promise<T[]> {
  const raw = await AsyncStorage.getItem(key);
  return raw ? (JSON.parse(raw) as T[]) : [];
}

async function setArray<T>(key: string, value: T[]): Promise<void> {
  await AsyncStorage.setItem(key, JSON.stringify(value));
}

export async function getObject<T>(key: string): Promise<T | null> {
  const raw = await AsyncStorage.getItem(key);
  return raw ? (JSON.parse(raw) as T) : null;
}

export async function setObject<T>(key: string, value: T): Promise<void> {
  await AsyncStorage.setItem(key, JSON.stringify(value));
}

interface QueuedItem {
  type: "food_log" | "symptom_log";
  data: unknown;
  created_at: string;
}

export async function queueFoodLog(log: CreateFoodLogRequest): Promise<void> {
  const queue = await getArray<QueuedItem>(OFFLINE_QUEUE);
  queue.push({ type: "food_log", data: log, created_at: new Date().toISOString() });
  await setArray(OFFLINE_QUEUE, queue);
}

export async function queueSymptom(data: unknown): Promise<void> {
  const queue = await getArray<QueuedItem>(OFFLINE_QUEUE);
  queue.push({ type: "symptom_log", data, created_at: new Date().toISOString() });
  await setArray(OFFLINE_QUEUE, queue);
}

export async function getOfflineQueue(): Promise<QueuedItem[]> {
  return getArray<QueuedItem>(OFFLINE_QUEUE);
}

export async function clearOfflineQueue(): Promise<void> {
  await setArray(OFFLINE_QUEUE, []);
}

export const offlineCache = {
  allergyCard: (lang: string) => getObject(`allergy_card_${lang}`),
  setAllergyCard: (lang: string, v: unknown) => setObject(`allergy_card_${lang}`, v),
  todayLog: () => getObject("today_log"),
  setTodayLog: (v: unknown) => setObject("today_log", v),
  userProfile: () => getObject("user_profile"),
  setUserProfile: (v: unknown) => setObject("user_profile", v),
};
