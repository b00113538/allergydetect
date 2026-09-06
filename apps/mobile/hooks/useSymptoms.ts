import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { api } from "@/lib/api";

export function useWeeklySymptoms() {
  return useQuery({ queryKey: ["symptom-weekly"], queryFn: () => api.symptomWeeklySummary() });
}

export function useCreateSymptom() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (payload: Parameters<typeof api.createSymptom>[0]) => api.createSymptom(payload),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["symptom-weekly"] });
      qc.invalidateQueries({ queryKey: ["allergen-candidates"] });
      qc.invalidateQueries({ queryKey: ["insights"] });
    },
  });
}
