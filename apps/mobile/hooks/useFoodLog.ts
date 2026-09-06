import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { api } from "@/lib/api";
import { scheduleMealFollowUp } from "@/lib/notifications";
import type { CreateFoodLogRequest } from "@/types";

export function useToday() {
  return useQuery({ queryKey: ["today"], queryFn: () => api.today() });
}

export function useFrequentIngredients() {
  return useQuery({ queryKey: ["frequent"], queryFn: () => api.frequentIngredients() });
}

export function useCreateFoodLog() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (payload: CreateFoodLogRequest) => api.createFoodLog(payload),
    onSuccess: async (log) => {
      await scheduleMealFollowUp(log.meal_type, log.id);
      qc.invalidateQueries({ queryKey: ["today"] });
      qc.invalidateQueries({ queryKey: ["frequent"] });
    },
  });
}

export function useFoodLog(id: string) {
  return useQuery({ queryKey: ["food-log", id], queryFn: () => api.getFoodLog(id), enabled: !!id });
}

export function useDeleteFoodLog() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => api.deleteFoodLog(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["today"] }),
  });
}
