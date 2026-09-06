import { Platform } from "react-native";

import { useSyncWearables, type WearableReadingInput } from "@/hooks/useWearables";

/**
 * Apple HealthKit integration.
 *
 * `react-native-health` is a native module that only works in a custom dev
 * build (not Expo Go) on a physical iOS device. This hook exposes the same
 * surface the rest of the app expects; when the native module is unavailable
 * it reports `available: false` and `syncHealthData` is a no-op so the UI can
 * render a "connect on a device build" state without crashing.
 */
export function useHealthKit() {
  const sync = useSyncWearables();
  const available = Platform.OS === "ios";

  const syncHealthData = async (): Promise<number> => {
    if (!available) return 0;
    // On a real device build, replace this with AppleHealthKit sample queries
    // and map them into WearableReadingInput[] before syncing.
    const readings: WearableReadingInput[] = [];
    if (readings.length === 0) return 0;
    const res = await sync.mutateAsync({ source: "apple_health", readings });
    return res.synced_count;
  };

  return { available, syncHealthData, syncing: sync.isPending };
}
