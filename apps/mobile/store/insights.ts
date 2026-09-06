import { create } from "zustand";

import type { AllergenCandidate } from "@/types";

interface EliminationTest {
  ingredient: string;
  startedAt: string;
}

interface InsightsState {
  candidates: AllergenCandidate[];
  elimination: EliminationTest | null;
  setCandidates: (c: AllergenCandidate[]) => void;
  startElimination: (ingredient: string) => void;
  stopElimination: () => void;
  eliminationDay: () => number | null;
}

export const useInsightsStore = create<InsightsState>((set, get) => ({
  candidates: [],
  elimination: null,
  setCandidates: (candidates) => set({ candidates }),
  startElimination: (ingredient) =>
    set({ elimination: { ingredient, startedAt: new Date().toISOString() } }),
  stopElimination: () => set({ elimination: null }),
  eliminationDay: () => {
    const e = get().elimination;
    if (!e) return null;
    const diff = Date.now() - new Date(e.startedAt).getTime();
    return Math.floor(diff / (24 * 60 * 60 * 1000)) + 1;
  },
}));
