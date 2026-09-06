import { create } from "zustand";

import { api, setUnauthorizedHandler } from "@/lib/api";
import { tokenStore } from "@/lib/storage";
import type { Allergy, Goal, User } from "@/types";

interface AuthState {
  user: User | null;
  goals: Goal[];
  allergies: Allergy[];
  status: "loading" | "authenticated" | "unauthenticated";
  bootstrap: () => Promise<void>;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string, name: string) => Promise<void>;
  logout: () => Promise<void>;
  refreshMe: () => Promise<void>;
  setUser: (user: User) => void;
}

export const useAuthStore = create<AuthState>((set, get) => ({
  user: null,
  goals: [],
  allergies: [],
  status: "loading",

  bootstrap: async () => {
    setUnauthorizedHandler(() => set({ user: null, status: "unauthenticated" }));
    const token = await tokenStore.getAccess();
    if (!token) {
      set({ status: "unauthenticated" });
      return;
    }
    try {
      const me = await api.me();
      set({ user: me.user, goals: me.goals, allergies: me.allergies, status: "authenticated" });
    } catch {
      set({ status: "unauthenticated" });
    }
  },

  login: async (email, password) => {
    const res = await api.login(email, password);
    set({ user: res.user, status: "authenticated" });
    await get().refreshMe();
  },

  register: async (email, password, name) => {
    const res = await api.register(email, password, name);
    set({ user: res.user, status: "authenticated" });
  },

  logout: async () => {
    await api.logout();
    set({ user: null, goals: [], allergies: [], status: "unauthenticated" });
  },

  refreshMe: async () => {
    const me = await api.me();
    set({ user: me.user, goals: me.goals, allergies: me.allergies });
  },

  setUser: (user) => set({ user }),
}));
