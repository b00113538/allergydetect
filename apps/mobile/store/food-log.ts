import { create } from "zustand";

import { api } from "@/lib/api";
import {
  clearOfflineQueue,
  getOfflineQueue,
  queueFoodLog,
} from "@/lib/storage";
import type { CreateFoodLogRequest, TodayResponse } from "@/types";

interface FoodLogState {
  today: TodayResponse | null;
  water_ml: number;
  loadToday: () => Promise<void>;
  addLog: (payload: CreateFoodLogRequest, online?: boolean) => Promise<void>;
  addWater: (ml: number) => void;
  drainQueue: () => Promise<void>;
}

export const useFoodLogStore = create<FoodLogState>((set, get) => ({
  today: null,
  water_ml: 0,

  loadToday: async () => {
    const today = await api.today();
    set({ today });
  },

  addLog: async (payload, online = true) => {
    if (!online) {
      await queueFoodLog(payload);
      return;
    }
    try {
      await api.createFoodLog(payload);
      await get().loadToday();
    } catch {
      await queueFoodLog(payload);
    }
  },

  addWater: (ml) => set((s) => ({ water_ml: s.water_ml + ml })),

  drainQueue: async () => {
    const queue = await getOfflineQueue();
    for (const item of queue) {
      try {
        if (item.type === "food_log") {
          await api.createFoodLog(item.data as CreateFoodLogRequest);
        } else if (item.type === "symptom_log") {
          await api.createSymptom(item.data as Parameters<typeof api.createSymptom>[0]);
        }
      } catch {
        return; // stop on first failure; retry next time
      }
    }
    await clearOfflineQueue();
    await get().loadToday();
  },
}));
