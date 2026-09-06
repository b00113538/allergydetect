import { create } from "zustand";

import { api } from "@/lib/api";
import type { Allergy, Goal, User } from "@/types";
import { useAuthStore } from "@/store/auth";

interface UserState {
  saving: boolean;
  updateProfile: (payload: Partial<User>) => Promise<void>;
  saveGoal: (payload: Partial<Goal> & { goal_type: string }) => Promise<void>;
  addAllergy: (a: { allergen_name: string; severity: string; allergen_category?: string; confirmed_by_doctor?: boolean }) => Promise<Allergy>;
  removeAllergy: (id: string) => Promise<void>;
}

export const useUserStore = create<UserState>((set) => ({
  saving: false,
  updateProfile: async (payload) => {
    set({ saving: true });
    try {
      const user = await api.updateProfile(payload);
      useAuthStore.getState().setUser(user);
    } finally {
      set({ saving: false });
    }
  },
  saveGoal: async (payload) => {
    set({ saving: true });
    try {
      await api.upsertGoal(payload);
      await useAuthStore.getState().refreshMe();
    } finally {
      set({ saving: false });
    }
  },
  addAllergy: async (a) => {
    const allergy = await api.addAllergy(a);
    await useAuthStore.getState().refreshMe();
    return allergy;
  },
  removeAllergy: async (id) => {
    await api.deleteAllergy(id);
    await useAuthStore.getState().refreshMe();
  },
}));
