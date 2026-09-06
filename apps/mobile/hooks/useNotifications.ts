import { useEffect } from "react";
import { Platform } from "react-native";

import { api } from "@/lib/api";
import { registerForPush } from "@/lib/notifications";

export function useRegisterPush(enabled: boolean) {
  useEffect(() => {
    if (!enabled) return;
    (async () => {
      const token = await registerForPush();
      if (token) {
        try {
          await api.registerPushToken(token, Platform.OS);
        } catch {
          /* best-effort */
        }
      }
    })();
  }, [enabled]);
}
