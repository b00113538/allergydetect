import { useMemo } from "react";

import type { StreakInfo } from "@/types";

// The /auth/me payload does not include streaks; the home screen derives a
// display set from the today response + known streak types. A dedicated
// /streaks endpoint can replace this later.
export function useStreaks(loggingCount: number, reactionFreeDays: number): StreakInfo[] {
  return useMemo(
    () => [
      { type: "logging", current: loggingCount, record: loggingCount },
      { type: "reaction_free", current: reactionFreeDays, record: reactionFreeDays },
    ],
    [loggingCount, reactionFreeDays]
  );
}
