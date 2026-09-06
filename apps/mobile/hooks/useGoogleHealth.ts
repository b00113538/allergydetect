import { Platform } from "react-native";

import { useSyncWearables, type WearableReadingInput } from "@/hooks/useWearables";

/**
 * Android Health Connect integration via `react-native-google-fit`.
 * Requires a custom dev build on a physical Android device. See useHealthKit
 * for the same rationale; this is a graceful, type-safe placeholder.
 */
export function useGoogleHealth() {
  const sync = useSyncWearables();
  const available = Platform.OS === "android";

  const syncHealthData = async (): Promise<number> => {
    if (!available) return 0;
    const readings: WearableReadingInput[] = [];
    if (readings.length === 0) return 0;
    const res = await sync.mutateAsync({ source: "google_health", readings });
    return res.synced_count;
  };

  return { available, syncHealthData, syncing: sync.isPending };
}
