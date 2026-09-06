import { useQuery } from "@tanstack/react-query";

import { api } from "@/lib/api";

export function useAllergenCandidates() {
  return useQuery({ queryKey: ["allergen-candidates"], queryFn: () => api.allergenCandidates() });
}

export function useRecentInsights() {
  return useQuery({ queryKey: ["insights"], queryFn: () => api.recentInsights() });
}

export function useDailyInsight() {
  return useQuery({ queryKey: ["daily-insight"], queryFn: () => api.dailyInsight() });
}
