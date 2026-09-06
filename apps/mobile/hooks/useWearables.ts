import { useMutation, useQuery } from "@tanstack/react-query";

import { api } from "@/lib/api";

export interface WearableReadingInput {
  metric: string;
  value: number;
  unit?: string;
  recorded_at: string;
}

export function useWearableSummary(days = 7) {
  return useQuery({ queryKey: ["wearable-summary", days], queryFn: () => api.wearableSummary(days) });
}

export function useSyncWearables() {
  return useMutation({
    mutationFn: ({ source, readings }: { source: string; readings: WearableReadingInput[] }) =>
      api.syncWearables(source, readings),
  });
}
